## Contiguous Json

Reads through the json string only in the forward direction and fills in your struct type allocating only in contiguous memory. Also writes json using quite a lot of compile time generated code.

### Notes

If you want your objects to be naturally useable after parsing, but harder to free in memory, disable contiguous mode. For example, a resizable array created in contiguous mode doesn't own the block of data that it points to.

To mark an element as optional just make it a pointer in your struct.

This library approximates floating point width accuracy when compared to javascript. The data won't be exactly the same. Generally this library has an extra digit or two of accuracy.

Parsing a GLTF blob in contiguous memory mode: `0.1195` milliseconds.
Parsing a GLTF blob in normal (non-contiguous) memory mode: `0.1210` milliseconds.
Parsing a GLTF blob in javascript (node): `0.1180` milliseconds.
Other C style parsers I tested on the same GLTF blob: ~`0.2500` milliseconds.

### Support

Supports:
  * structs
  * resizable arrays
  * fixed arrays
  * array views
  * all integer types
  * all float types
  * all enum types
  * booleans
  * pointer and null types
  * in place and allocated strings `points to the substring in the json blob or copies the string memory`
  * optional values `allocates a pointer in memory`
  * contiguous and normal memory models `all memory as a single block or allocated as expected`
  * renaming values `@json(name)`
  * ignore reading/writing values `@jsonignore`

Does not support:
  * unicode, I think... because any value of `"` except `\"` will escape a quote

Any memory that needs to be allocated gets allocated into a contiguous block of memory that can be freed in a single call.

The tradeoff of this is all the data is treated as a relative offset into memory while processing the json string. This adds a little bit of overhead. After all the data has been read there is a single pass to convert all the relative offsets into absolute pointers into the contiguous memory. This also adds a bit of overhead.

The benefit is memory allocations are very cheap, so it's reasonable to use pointers to indicate optional values. It's also very easy and quick to free your json data when you're done with it.

---

### Setup

I fixed this line in `string_to_int` to get the code working properly:
`multiplier := 1;` -> `multiplier: T = 1;`

I reported this bug so should be fixed soon.