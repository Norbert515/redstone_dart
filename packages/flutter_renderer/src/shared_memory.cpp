#include "shared_memory.h"

#include <cstring>
#include <iostream>

#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

FlutterSharedMemoryHandle::FlutterSharedMemoryHandle() = default;

FlutterSharedMemoryHandle::~FlutterSharedMemoryHandle() {
    close();
}

bool FlutterSharedMemoryHandle::create(const char* name) {
    if (memory_ != nullptr) {
        std::cerr << "[FlutterShm] Already initialized" << std::endl;
        return false;
    }

    strncpy(name_, name, sizeof(name_) - 1);
    name_[sizeof(name_) - 1] = '\0';
    is_owner_ = true;

    const size_t shm_size = sizeof(FlutterSharedMemory);

#ifdef _WIN32
    // Windows implementation
    file_mapping_ = CreateFileMappingA(
        INVALID_HANDLE_VALUE,
        nullptr,
        PAGE_READWRITE,
        static_cast<DWORD>(shm_size >> 32),
        static_cast<DWORD>(shm_size & 0xFFFFFFFF),
        name_
    );

    if (file_mapping_ == nullptr) {
        std::cerr << "[FlutterShm] Failed to create file mapping: " << GetLastError() << std::endl;
        return false;
    }

    memory_ = static_cast<FlutterSharedMemory*>(
        MapViewOfFile(file_mapping_, FILE_MAP_ALL_ACCESS, 0, 0, shm_size)
    );

    if (memory_ == nullptr) {
        std::cerr << "[FlutterShm] Failed to map view: " << GetLastError() << std::endl;
        CloseHandle(file_mapping_);
        file_mapping_ = nullptr;
        return false;
    }
#else
    // POSIX implementation (macOS/Linux)

    // Ensure name starts with /
    char shm_name[256];
    if (name_[0] != '/') {
        snprintf(shm_name, sizeof(shm_name), "/%s", name_);
    } else {
        strncpy(shm_name, name_, sizeof(shm_name) - 1);
        shm_name[sizeof(shm_name) - 1] = '\0';
    }

    // Remove any existing shm with this name
    shm_unlink(shm_name);

    // Create shared memory
    fd_ = shm_open(shm_name, O_CREAT | O_RDWR, 0666);
    if (fd_ == -1) {
        std::cerr << "[FlutterShm] Failed to create shared memory: " << strerror(errno) << std::endl;
        return false;
    }

    // Set size
    if (ftruncate(fd_, shm_size) == -1) {
        std::cerr << "[FlutterShm] Failed to set shared memory size: " << strerror(errno) << std::endl;
        ::close(fd_);
        fd_ = -1;
        shm_unlink(shm_name);
        return false;
    }

    // Map memory
    void* ptr = mmap(nullptr, shm_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd_, 0);
    if (ptr == MAP_FAILED) {
        std::cerr << "[FlutterShm] Failed to map shared memory: " << strerror(errno) << std::endl;
        ::close(fd_);
        fd_ = -1;
        shm_unlink(shm_name);
        return false;
    }

    memory_ = static_cast<FlutterSharedMemory*>(ptr);

    // Update name_ with the actual shm name used
    strncpy(name_, shm_name, sizeof(name_) - 1);
#endif

    // Initialize the shared memory structure
    std::memset(memory_, 0, sizeof(FlutterSharedMemory));
    memory_->magic.store(FLUTTER_SHM_MAGIC, std::memory_order_release);
    memory_->status.store(STATUS_NOT_READY, std::memory_order_release);

    std::cout << "[FlutterShm] Created shared memory: " << name_ << " (" << shm_size << " bytes)" << std::endl;
    return true;
}

bool FlutterSharedMemoryHandle::open(const char* name) {
    if (memory_ != nullptr) {
        std::cerr << "[FlutterShm] Already initialized" << std::endl;
        return false;
    }

    strncpy(name_, name, sizeof(name_) - 1);
    name_[sizeof(name_) - 1] = '\0';
    is_owner_ = false;

    const size_t shm_size = sizeof(FlutterSharedMemory);

#ifdef _WIN32
    // Windows implementation
    file_mapping_ = OpenFileMappingA(FILE_MAP_ALL_ACCESS, FALSE, name_);

    if (file_mapping_ == nullptr) {
        std::cerr << "[FlutterShm] Failed to open file mapping: " << GetLastError() << std::endl;
        return false;
    }

    memory_ = static_cast<FlutterSharedMemory*>(
        MapViewOfFile(file_mapping_, FILE_MAP_ALL_ACCESS, 0, 0, shm_size)
    );

    if (memory_ == nullptr) {
        std::cerr << "[FlutterShm] Failed to map view: " << GetLastError() << std::endl;
        CloseHandle(file_mapping_);
        file_mapping_ = nullptr;
        return false;
    }
#else
    // POSIX implementation (macOS/Linux)

    // Ensure name starts with /
    char shm_name[256];
    if (name_[0] != '/') {
        snprintf(shm_name, sizeof(shm_name), "/%s", name_);
    } else {
        strncpy(shm_name, name_, sizeof(shm_name) - 1);
        shm_name[sizeof(shm_name) - 1] = '\0';
    }

    // Open existing shared memory
    fd_ = shm_open(shm_name, O_RDWR, 0666);
    if (fd_ == -1) {
        std::cerr << "[FlutterShm] Failed to open shared memory: " << strerror(errno) << std::endl;
        return false;
    }

    // Map memory
    void* ptr = mmap(nullptr, shm_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd_, 0);
    if (ptr == MAP_FAILED) {
        std::cerr << "[FlutterShm] Failed to map shared memory: " << strerror(errno) << std::endl;
        ::close(fd_);
        fd_ = -1;
        return false;
    }

    memory_ = static_cast<FlutterSharedMemory*>(ptr);

    // Update name_ with the actual shm name used
    strncpy(name_, shm_name, sizeof(name_) - 1);
#endif

    // Validate magic number
    if (memory_->magic.load(std::memory_order_acquire) != FLUTTER_SHM_MAGIC) {
        std::cerr << "[FlutterShm] Invalid magic number in shared memory" << std::endl;
        close();
        return false;
    }

    std::cout << "[FlutterShm] Opened shared memory: " << name_ << std::endl;
    return true;
}

void FlutterSharedMemoryHandle::close() {
    if (memory_ == nullptr) {
        return;
    }

    const size_t shm_size = sizeof(FlutterSharedMemory);

#ifdef _WIN32
    UnmapViewOfFile(memory_);
    memory_ = nullptr;

    if (file_mapping_ != nullptr) {
        CloseHandle(file_mapping_);
        file_mapping_ = nullptr;
    }
#else
    munmap(memory_, shm_size);
    memory_ = nullptr;

    if (fd_ != -1) {
        ::close(fd_);
        fd_ = -1;
    }
#endif

    std::cout << "[FlutterShm] Closed shared memory: " << name_ << std::endl;
}

void FlutterSharedMemoryHandle::unlink() {
    if (!is_owner_ || name_[0] == '\0') {
        return;
    }

#ifdef _WIN32
    // Windows automatically cleans up when all handles are closed
#else
    shm_unlink(name_);
    std::cout << "[FlutterShm] Unlinked shared memory: " << name_ << std::endl;
#endif
}
