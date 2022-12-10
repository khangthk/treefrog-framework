#pragma once
#include <TGlobal>

class TSharedMemory;

namespace Tf {
struct program_break_header_t;
struct alloc_header_t;
}


class T_CORE_EXPORT TSharedMemoryAllocator {
public:
    //TSharedMemoryAllocator(const QString &name, size_t size);  // Shared memory
    virtual ~TSharedMemoryAllocator();

    void *malloc(uint size);
    void *calloc(uint num, uint nsize);
    void *realloc(void *ptr, uint size);
    void free(void *ptr);
    uint allocSize(const void *ptr);
#if 0
    size_t mapSize() const { return _size; }
    bool isNew() const { return _newmap; }
#else
    size_t mapSize() const;
    //bool isNew() const;
#endif
    void *origin() const { return (void *)_origin; }

    // Internal use
    void summary();
    void dump();  // For debug
    int nblocks();  // Counts blocks

    static TSharedMemoryAllocator *create(const QString &name, size_t size);
    static TSharedMemoryAllocator *attach(const QString &name);
    static void unlink(const QString &name);

private:
    TSharedMemoryAllocator(const QString &name);  // constructor
    caddr_t sbrk(int64_t inc);
    //void *setbrk(void *start, uint size, bool initial = false);
    void setbrk(bool initial = false);
    Tf::alloc_header_t *free_block(uint size);

#if 0
    QString _name;
    size_t _size {0};
    void *_shm {nullptr};
    bool _newmap {true};
#else
    TSharedMemory *_sharedMemory {nullptr};
#endif
    caddr_t _origin {nullptr};
    Tf::program_break_header_t *pb_header {nullptr};

    T_DISABLE_COPY(TSharedMemoryAllocator)
    T_DISABLE_MOVE(TSharedMemoryAllocator)
};
