## Contiguous Json

This library reads through the json string only in the forward direction and fills in your struct type allocating only in contiguous memory.

Supports:
  * structs
  * resizable arrays
  * fixed arrays
  * all integer types
  * all float types
  * all enum types
  * booleans
  * in place strings `points to the string in the json`
  * allocated strings `copies the string in the json`
  * optional values `creates a pointer in contiguous memory`
  * renaming values `@json(name)`

Any memory that needs to be allocated gets allocated into a contiguous block of memory that can be freed in a single call.

The tradeoff of this is all the data is treated as a relative offset into memory while processing the json string. This adds a little bit of overhead. After all the data has been read there is a single pass to convert all the relative offsets into absolute pointers into the contiguous memory. This also adds a bit of overhead.

The benefit is memory allocations are very cheap, so it's reasonable to use pointers to indicate optional values. It's also very easy and quick to free your json data when you're done with it.

---

### TODO

Going to try more test cases but it's annoying because I still have to make a struct for each case.

Going to finish the writer which should be infinitely easier than the reader.

---

### Setup

I fixed this line in `string_to_int` to get the code working properly:
`multiplier := 1;` -> `multiplier: T = 1;`