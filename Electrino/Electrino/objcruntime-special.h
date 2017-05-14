//
//  objcruntime-special.h
//  Electrino
//
//  Created by George Dan on 12/5/17.
//  Copyright © 2017 Lacquer. All rights reserved.
//

#ifndef objcruntime_special_h
#define objcruntime_special_h


typedef uintptr_t cache_key_t;

#if __LP64__
typedef uint32_t mask_t;
#   define MASK_SHIFT ((mask_t)0)
#else
typedef uint16_t mask_t;
#   define MASK_SHIFT ((mask_t)0)
#endif

struct cache_t {
	struct bucket_t *buckets;
	mask_t shiftmask;
	mask_t occupied;
	
	mask_t mask() {
		return shiftmask >> MASK_SHIFT;
	}
	mask_t capacity() {
		return shiftmask ? (shiftmask >> MASK_SHIFT) + 1 : 0;
	}
	void setCapacity(uint32_t capacity) {
		uint32_t newmask = (capacity - 1) << MASK_SHIFT;
		assert(newmask == (uint32_t)(mask_t)newmask);
		shiftmask = newmask;
	}
	
	void expand();
	void reallocate(mask_t oldCapacity, mask_t newCapacity);
	struct bucket_t * find(cache_key_t key);
	
	static void bad_cache(id receiver, SEL sel, Class isa, bucket_t *bucket) __attribute__((noreturn));
};


typedef struct classref * classref_t;

struct method_t {
	SEL name;
	const char *types;
	IMP imp;
	
	struct SortBySELAddress :
	public std::binary_function<const method_t&,
	const method_t&, bool>
	{
		bool operator() (const method_t& lhs,
						 const method_t& rhs)
		{ return lhs.name < rhs.name; }
	};
};

struct method_list_t {
	uint32_t entsize_NEVER_USE;  // high bits used for fixup markers
	uint32_t count;
	method_t first;
	
	uint32_t getEntsize() const {
		return entsize_NEVER_USE & ~(uint32_t)3;
	}
	uint32_t getCount() const {
		return count;
	}
	method_t& getOrEnd(uint32_t i) const {
		assert(i <= count);
		return *(method_t *)((uint8_t *)&first + i*getEntsize());
	}
	method_t& get(uint32_t i) const {
		assert(i < count);
		return getOrEnd(i);
	}
	
	// iterate methods, taking entsize into account
	// fixme need a proper const_iterator
	struct method_iterator {
		uint32_t entsize;
		uint32_t index;  // keeping track of this saves a divide in operator-
		method_t* method;
		
		typedef std::random_access_iterator_tag iterator_category;
		typedef method_t value_type;
		typedef ptrdiff_t difference_type;
		typedef method_t* pointer;
		typedef method_t& reference;
		
		method_iterator() { }
		
		method_iterator(const method_list_t& mlist, uint32_t start = 0)
		: entsize(mlist.getEntsize())
		, index(start)
		, method(&mlist.getOrEnd(start))
		{ }
		
		const method_iterator& operator += (ptrdiff_t delta) {
			method = (method_t*)((uint8_t *)method + delta*entsize);
			index += (int32_t)delta;
			return *this;
		}
		const method_iterator& operator -= (ptrdiff_t delta) {
			method = (method_t*)((uint8_t *)method - delta*entsize);
			index -= (int32_t)delta;
			return *this;
		}
		const method_iterator operator + (ptrdiff_t delta) const {
			return method_iterator(*this) += delta;
		}
		const method_iterator operator - (ptrdiff_t delta) const {
			return method_iterator(*this) -= delta;
		}
		
		method_iterator& operator ++ () { *this += 1; return *this; }
		method_iterator& operator -- () { *this -= 1; return *this; }
		method_iterator operator ++ (int) {
			method_iterator result(*this); *this += 1; return result;
		}
		method_iterator operator -- (int) {
			method_iterator result(*this); *this -= 1; return result;
		}
		
		ptrdiff_t operator - (const method_iterator& rhs) const {
			return (ptrdiff_t)this->index - (ptrdiff_t)rhs.index;
		}
		
		method_t& operator * () const { return *method; }
		method_t* operator -> () const { return method; }
		
		operator method_t& () const { return *method; }
		
		bool operator == (const method_iterator& rhs) {
			return this->method == rhs.method;
		}
		bool operator != (const method_iterator& rhs) {
			return this->method != rhs.method;
		}
		
		bool operator < (const method_iterator& rhs) {
			return this->method < rhs.method;
		}
		bool operator > (const method_iterator& rhs) {
			return this->method > rhs.method;
		}
	};
	
	method_iterator begin() const { return method_iterator(*this, 0); }
	method_iterator end() const { return method_iterator(*this, getCount()); }
	
};

struct ivar_t {
#if __x86_64__
	// *offset was originally 64-bit on some x86_64 platforms.
	// We read and write only 32 bits of it.
	// Some metadata provides all 64 bits. This is harmless for unsigned
	// little-endian values.
	// Some code uses all 64 bits. class_addIvar() over-allocates the
	// offset for their benefit.
#endif
	int32_t *offset;
	const char *name;
	const char *type;
	// alignment is sometimes -1; use alignment() instead
	uint32_t alignment_raw;
	uint32_t size;
	
	uint32_t alignment() {
		if (alignment_raw == ~(uint32_t)0) return 1U << 3UL;
		return 1 << alignment_raw;
	}
};

struct ivar_list_t {
	uint32_t entsize;
	uint32_t count;
	ivar_t first;
};

struct property_t {
	const char *name;
	const char *attributes;
};

struct property_list_t {
	uint32_t entsize;
	uint32_t count;
	property_t first;
};

typedef uintptr_t protocol_ref_t;  // protocol_t *, but unremapped

#define PROTOCOL_FIXED_UP (1<<31)  // must never be set by compiler

struct protocol_t : objc_object {
	const char *name;
	struct protocol_list_t *protocols;
	method_list_t *instanceMethods;
	method_list_t *classMethods;
	method_list_t *optionalInstanceMethods;
	method_list_t *optionalClassMethods;
	property_list_t *instanceProperties;
	uint32_t size;   // sizeof(protocol_t)
	uint32_t flags;
	const char **extendedMethodTypes;
};

struct protocol_list_t {
	// count is 64-bit by accident.
	uintptr_t count;
	protocol_ref_t list[0]; // variable-size
};


struct class_ro_t {
	uint32_t flags;
	uint32_t instanceStart;
	uint32_t instanceSize;
#ifdef __LP64__
	uint32_t reserved;
#endif
	
	const uint8_t * ivarLayout;
	
	const char * name;
	const method_list_t * baseMethods;
	const protocol_list_t * baseProtocols;
	const ivar_list_t * ivars;
	
	const uint8_t * weakIvarLayout;
	const property_list_t *baseProperties;
};

struct class_rw_t {
	uint32_t flags;
	uint32_t version;
	
	const class_ro_t *ro;
	
	union {
		method_list_t **method_lists;  // RW_METHOD_ARRAY == 1
		method_list_t *method_list;    // RW_METHOD_ARRAY == 0
	};
	struct chained_property_list *properties;
	const protocol_list_t ** protocols;
	
	Class firstSubclass;
	Class nextSiblingClass;
};


struct objc_class_t {
	Class isa;
	
//#if !__OBJC2__
	Class super_class                                        ;
	const char *name                                         ;
	long version                                             ;
	long info                                                ;
	long instance_size                                       ;
	struct objc_ivar_list *ivars                             ;
	struct objc_method_list **methodLists                    ;
	struct objc_cache *cache                                 ;
	struct objc_protocol_list *protocols                     ;
//#endif
	
};
#endif /* objcruntime_special_h */
