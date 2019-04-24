/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import "MGSRangeEntries.h"
#import <Foundation/NSString.h>

/* this could be improved with more merging of adjacent entries after insert/remove */

typedef struct MGSRangeEntry {
   NSRange range;
   id value;
} MGSRangeEntry;

struct MGSRangeEntries {
   NSUInteger             capacity;
   NSUInteger             count;
   struct MGSRangeEntry *entries;
};

 MGSRangeEntries *MGSCreateRangeToCopiedObjectEntries(NSUInteger capacity) {
   MGSRangeEntries *result=NSZoneMalloc(NULL,sizeof(MGSRangeEntries));

   result->capacity=(capacity<4)?4:capacity;
   result->count=0;
   result->entries = NSZoneCalloc(NULL, result->capacity, sizeof(MGSRangeEntry));

   return result;
}


void MGSFreeRangeEntries(MGSRangeEntries *self)
{
    if (self == NULL) {
         return;
    }
    MGSResetRangeEntries(self);
    NSZoneFree(NULL, self->entries);
    NSZoneFree(NULL, self);
}


 void MGSResetRangeEntries(MGSRangeEntries *self) {
   NSInteger i;

   for(i=0;i<self->count;i++)
    self->entries[i].value = nil;

   self->count=0;
}

 NSUInteger MGSCountRangeEntries(MGSRangeEntries *self) {
   return self->count;
}

static inline void removeEntryAtIndex(MGSRangeEntries *self,NSUInteger index){
	self->entries[index].value = nil;
	
	self->count--;
	for(;index<self->count;index++)
		self->entries[index]=self->entries[index+1];
}

static inline void insertEntryAtIndex(MGSRangeEntries *self,NSUInteger index,NSRange range,id value){
   NSInteger i;

   self->count++;
   if(self->count>self->capacity){
    self->capacity*=2;
    self->entries=NSZoneRealloc(NULL,self->entries,sizeof(MGSRangeEntry)*self->capacity);
       memset(self->entries + (self->count - 1), 0, (self->capacity - (self->count - 1)) * sizeof(MGSRangeEntry));
   }

   for(i=self->count;--i>index;)
    self->entries[i]=self->entries[i-1];

   value=[value copy];

   self->entries[index].range=range;
   self->entries[index].value=value;
}

void MGSRangeEntryInsert(MGSRangeEntries *self,NSRange range, id value) {
   NSInteger count=self->count;
   NSInteger bottom=0,top=count;
   NSInteger insertAt=0;

   if(count>0){
    while(top>=bottom){
     NSInteger     mid=(bottom+top)/2;
     NSRange check=self->entries[mid].range;

     if(range.location>=NSMaxRange(check)){
      NSInteger next=mid+1;

      if(next>=count || NSMaxRange(range)<=self->entries[next].range.location){
       insertAt=next;
       break;
      }
      bottom=mid+1;
     }
     else {
      NSInteger prev=mid-1;

      if(prev<0 || range.location>=NSMaxRange(self->entries[prev].range)){
       insertAt=mid;
       break;
      }
      top=mid-1;
     }
    }
   }
	BOOL merged = NO;
	if (range.length == 0) {
		// We'll just try to merge entries around the location
		if(insertAt>0 && insertAt<self->count){
			id prev = self->entries[insertAt-1].value;
			id next = self->entries[insertAt].value;
			if ([prev isEqual:next]) {
				range = NSUnionRange(self->entries[insertAt].range,self->entries[insertAt-1].range);
				self->entries[insertAt-1].range=range;
				removeEntryAtIndex(self, insertAt);
			}
		}
		// We don't really want to insert a 0 length entry
		return;
	} else {
			if(insertAt>0){
				// Check if we can just merge the new entry with the previous one
				if(range.length == 0 || [(id)(self->entries[insertAt-1].value) isEqual:value]){
					range = NSUnionRange(self->entries[insertAt-1].range,range);
					self->entries[insertAt-1].range=range;
					merged = YES;
				}
			}
			if(insertAt<self->count){
				// Check if we can just merge the new entry with the next one
				if(range.length == 0 || [(id)(self->entries[insertAt].value) isEqual:value]){
					range = NSUnionRange(self->entries[insertAt].range,range);
					if (merged) {
						// We merged with both the previous entry and the next one - the next one isn't needed anymore
						// so just merge it with the previous one
						self->entries[insertAt-1].range=range;
						removeEntryAtIndex(self, insertAt);
					} else {
						self->entries[insertAt].range=range;
					}
					merged = YES;;
				}
			}
	}
	if (merged == NO) {
		insertEntryAtIndex(self,insertAt,range,value);
	}
	
 }

id MGSRangeEntryAtIndex(MGSRangeEntries *self,NSUInteger location,NSRange *effectiveRangep) {
   NSInteger     count=self->count;
   NSInteger     bottom=0,top=count;

   if(top==0){
    if(effectiveRangep!=NULL)
     *effectiveRangep=NSMakeRange(0,NSNotFound);
    return NULL;
   }

   while(top>=bottom){
    NSInteger     mid=(bottom+top)/2;
    NSRange check=self->entries[mid].range;

    if(NSLocationInRange(location,check)){
     if(effectiveRangep!=NULL)
      *effectiveRangep=check;
     return self->entries[mid].value;
    }
    else if(location>=NSMaxRange(check)){
     NSInteger next=mid+1;

     if(next>=count){
      if(effectiveRangep!=NULL){
       effectiveRangep->location=NSMaxRange(check);
       effectiveRangep->length=NSNotFound;
      }
      return NULL;
     }
     else if(location<self->entries[next].range.location){
      if(effectiveRangep!=NULL){
       effectiveRangep->location=NSMaxRange(check);
       effectiveRangep->length=self->entries[next].range.location-NSMaxRange(check);
      }
      return NULL;
     }
     bottom=mid+1;
    }
    else {
     NSInteger prev=mid-1;

     if(prev<0){
      if(effectiveRangep!=NULL){
       effectiveRangep->location=0;
       effectiveRangep->length=check.location;
      }
      return NULL;
     }
     else if(location>=NSMaxRange(self->entries[prev].range)){
      if(effectiveRangep!=NULL){
       effectiveRangep->location=NSMaxRange(self->entries[prev].range);
       effectiveRangep->length=check.location-effectiveRangep->location;
      }
      return NULL;
     }
     top=mid-1;
    }
   }

   NSLog(@"not supposed to get here %d",__LINE__);
   return NULL;
}

id MGSRangeEntryAtRange(MGSRangeEntries *self,NSRange range) {
   NSInteger bottom=0,top=self->count;

   if(top>0){
    while(top>=bottom){
     NSInteger     mid=(bottom+top)/2;
     NSRange check=self->entries[mid].range;

     if(NSEqualRanges(range,check))
      return self->entries[mid].value;
     else if(range.location>=NSMaxRange(check))
      bottom=mid+1;
     else
      top=mid-1;
    }
   }

   return NULL;
}

 MGSRangeEnumerator MGSRangeEntryEnumerator(MGSRangeEntries *self) {
   MGSRangeEnumerator result;

   result.self=self;
   result.index=0;

   return result;
}

 BOOL NSNextRangeEnumeratorEntry(MGSRangeEnumerator *state,NSRange *rangep, id *valuep) {
   MGSRangeEntries *self=state->self;

   if(state->index>=self->count)
    return NO;

   *rangep=self->entries[state->index].range;
   *valuep=self->entries[state->index].value;
   state->index++;

   return YES;
}

void MGSRangeEntriesRemoveEntryAtIndex(MGSRangeEntries *self,NSUInteger index)
{
	removeEntryAtIndex(self, index);
}

 void MGSRangeEntriesExpandAndWipe(MGSRangeEntries *self,NSRange range,NSInteger delta) {
   NSInteger  count=self->count;
   NSUInteger max=NSMaxRange(range);
   enum { useBefore, useFirst, useAfter, useNone } useAttributes;

//NSLog(@"expand wipe %d %d by %d",range.location,range.length,delta);

   if(range.length>0)
    useAttributes=useFirst;
   else if(range.location>0)
    useAttributes=useBefore;
   else
    useAttributes=useAfter;

   while(--count>=0){
    NSRange check=self->entries[count].range;

    if(check.location>max)
     self->entries[count].range.location+=delta;
    else if(check.location==max){
     if(useAttributes==useAfter)
      self->entries[count].range.length+=delta;
     else
      self->entries[count].range.location+=delta;
    }
    else if(check.location>range.location){
     if(NSMaxRange(check)<=max)
      removeEntryAtIndex(self,count);
     else
      self->entries[count].range=NSMakeRange(max+delta,NSMaxRange(check)-max);
    }
    else if(check.location==range.location){
     if(delta<0 && -delta>=check.length)
      removeEntryAtIndex(self,count);
     else if(useAttributes==useFirst){
      self->entries[count].range.length=MAX(max+delta,NSMaxRange(check)+delta)-check.location;
      useAttributes=useNone;
     }
    }
    else if(check.location<range.location){
     if(NSMaxRange(check)<range.location)
      break;
     if(NSMaxRange(check)>=max)
      self->entries[count].range.length+=delta;
     else if(useAttributes==useBefore || useAttributes==useFirst)
      self->entries[count].range.length=(max+delta)-check.location;
     else
      self->entries[count].range.length=range.location-check.location;
    }
   }
}

void MGSRangeEntriesDivideAndConquer(MGSRangeEntries *self,NSRange range) {
	NSInteger  count=self->count;
	NSUInteger max=NSMaxRange(range);
	
	while(--count>=0){
		NSRange check=self->entries[count].range;
		
		if(check.location<max){
			NSUInteger maxCheck=NSMaxRange(check);
			
			if(check.location>=range.location){
				if(maxCheck<=max) {
					// The entry is completely covered by the added range - it's not needed anymore
					removeEntryAtIndex(self,count);
				} else {
					// Remove the part of the entry covered by the added range 
					self->entries[count].range.length=maxCheck-max;
					self->entries[count].range.location=max;
				}
			} else if(maxCheck<=range.location) {
				// The entry is completely before the new range - we're done
				break;
			} else {
				// The end of the entry is covered by the added one
				if(maxCheck>max) {
					insertEntryAtIndex(self,count+1,NSMakeRange(max,maxCheck-max),self->entries[count].value);
				}
				// Shorten the entry to make room for the added one
				self->entries[count].range.length=range.location-check.location;
			}
		}
	}
}

 void MGSRangeEntriesDump(MGSRangeEntries *self) {
   NSInteger i;

NSLog(@"DUMP BEGIN");
   for(i=0;i<self->count;i++)
    NSLog(@"**** %d %d %@",self->entries[i].range.location, self->entries[i].range.length,self->entries[i].value);
NSLog(@"DUMP END");
}


void MGSRangeEntriesDumpAndAbort(MGSRangeEntries *self)
{
    MGSRangeEntriesDump(self);
    __builtin_trap();
}


 void MGSRangeEntriesVerify(MGSRangeEntries *self,NSUInteger length) {
#if 0
   NSUInteger last=0;
   NSInteger     i;

   for(i=0;i<self->count;i++){
    NSRange range=self->entries[i].range;

    if(range.length==0 && length>0){
    NSLog(@"ZERO RANGE");
     MGSRangeEntriesDumpAndAbort (self);
    }
    if(range.location!=last){
    NSLog(@"RANGE GAP");
     MGSRangeEntriesDumpAndAbort (self);
    }
    last=NSMaxRange(range);
   }
   if(last!=length){
    NSLog(@"SHORT RANGES %d",length);
    MGSRangeEntriesDumpAndAbort (self);
   }
   if(self->count==0)
    NSLog(@"EMPTY");
#endif
}

