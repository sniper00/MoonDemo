#ifndef _AOI_H
#define _AOI_H

#include <stdint.h>
#include <stddef.h>

typedef void * (*aoi_Alloc)(void *ud, void * ptr, size_t sz);
typedef void (aoi_Callback)(void *ud, uint32_t watcher, uint32_t marker);

struct object {
	int ref;
	uint32_t id;
	int version;
	int mode;
	float last[3];
	float position[3];
};

struct object_set {
	int cap;
	int number;
	struct object ** slot;
};

struct pair_list {
	struct pair_list * next;
	struct object * watcher;
	struct object * marker;
	int watcher_version;
	int marker_version;
};

struct map_slot {
	uint32_t id;
	struct object * obj;
	int next;
};

struct map {
	int size;
	int lastfree;
	struct map_slot * slot;
};

struct aoi_space {
	aoi_Alloc alloc;
	void * alloc_ud;
	struct map * object;
	struct object_set * watcher_static;
	struct object_set * marker_static;
	struct object_set * watcher_move;
	struct object_set * marker_move;
	struct pair_list * hot;
};

struct aoi_space * aoi_create(aoi_Alloc alloc, void *ud);
struct aoi_space * aoi_new();
void aoi_release(struct aoi_space *);

// w(atcher) m(arker) d(rop)
void aoi_update(struct aoi_space * space , uint32_t id, const char * mode , float pos[3]);
void aoi_message(struct aoi_space *space, aoi_Callback cb, void *ud);

#endif
