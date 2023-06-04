
json_parse :: (content: string, $T: Type, $contiguous_memory: bool = true, $keep_strings_in_place: bool = false) -> T, *u8, bool {
    index := trim_right(content, 0);
    result: T;
    memory: [..] u8;
    if json_parse_into(content, index, *result, *memory, false, contiguous_memory, keep_strings_in_place) {
        #if contiguous_memory {
            if memory.data {
                pointer_offset := cast(int) memory.data - 1;

                json_object_update_pointers :: (object: *JsonGeneric, pointer_offset: int) {
                    if object.type == .Object {
                        if object.object.data {
                            object.object.data = xx ((cast(*u8) object.object.data) + pointer_offset);
                            for *entry: object.object {
                                #if !keep_strings_in_place {
                                    if entry.name.data {
                                        entry.name.data = xx ((cast(*u8) entry.name.data) + pointer_offset);
                                    }
                                }

                                json_object_update_pointers(*entry.value, pointer_offset);
                            }
                        }
                    } else if object.type == .Array {
                        if object.array.data {
                            object.array.data = xx ((cast(*u8) object.array.data) + pointer_offset);
                            for *entry: object.array {
                                json_object_update_pointers(entry, pointer_offset);
                            }
                        }
                    } else if object.type == .String {
                        #if !keep_strings_in_place {
                            if object.str.data {
                                object.str.data = xx ((cast(*u8) object.str.data) + pointer_offset);
                            }
                        }
                    }
                }

                #insert #run get_pointer_update_string(T, "result", keep_strings_in_place);
            }
        }

        return result, memory.data, true;
    } else {
        return result, memory.data, false;
    }
}

#scope_file

// expected that these functions get provided the next non-whitespace index, but are allowed to return a whitespace index

json_parse_into :: (content: string, index: int, result: *JsonGeneric, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    union_offset :: #run get_member_offset(JsonGeneric, ""); // this gets the union
    entry_value_offset :: #run get_member_offset(JsonObjectEntry, "value");

    if index < content.count {
        if content.data[index] == #char "{" {
            #if contiguous_memory {
                absolute(result, memory.data, relative).type = .Object;
            } else {
                result.type = .Object;
            }

            index = trim_right(content, index + 1);

            // check for immediate close
            if index < content.count && content.data[index] == #char "}" {
                return index + 1, true;
            }

            object_entries, success := get_object_entries_until_closing_bracket(content, index);
            if !success {
                return index, false;
            }

            #if contiguous_memory {
            // ill leave allocated as 0 since its not allocating into the array, I guess
                required_bytes := object_entries * size_of(JsonObjectEntry);
                offset, allocated := allocate(memory, required_bytes, JsonObjectEntry, initialize = true, resizable_array = true);
                absolute(result, memory.data, relative).object.data = offset;
                absolute(result, memory.data, relative).object.count = object_entries;
            } else {
                arr: [..] JsonObjectEntry;
                array_resize(*arr, object_entries);
                result.object = arr;
            }

            // skip the next quote
            entry_index := 0;
            while index < content.count && entry_index < object_entries {
                #if ASSERT {
                    assert(index < content.count && content.data[index] == #char "\"", "Missing quote.");
                }
                index += 1;

                name, found := get_string_until_closing_quote(content, index);
                if !found {
                    return index, false;
                }

                index = trim_right(content, index + name.count + 1);
                #if ASSERT {
                    assert(index < content.count && content.data[index] == #char ":", "Missing colon.");
                }

                // now we're starting on the inner value
                index = trim_right(content, index + 1);

                entry_name: string = ---;
                #if keep_strings_in_place {
                    entry_name = name;
                } else {
                    #if contiguous_memory {
                        offset, allocated := allocate(memory, name.count, u8);
                        entry_name.data = offset;
                        entry_name.count = name.count;
                        memcpy(allocated, name.data, name.count);
                    } else {
                        entry_name = copy_string(name);
                    }
                }

                #if contiguous_memory {
                    entry := absolute(result, memory.data, relative).object.data + entry_index;
                    absolute(entry, memory.data, true).name = entry_name;
                } else {
                    entry := result.object.data + entry_index;
                    entry.name = entry_name;
                }
                index, success = json_parse_into(content, index, cast(*JsonGeneric) (cast(*u8) entry + entry_value_offset), memory, true, contiguous_memory, keep_strings_in_place);
                if !success {
                    return index, false;
                }

                index = trim_right(content, index);
                #if ASSERT {
                    assert(index < content.count && content.data[index] == #char "," || content.data[index] == #char "}", "Missing comma or right bracket.");
                }
                if index < content.count && content.data[index] == #char "}" {
                    return index + 1, true;
                }

                // move on to get the next member
                index = trim_right(content, index + 1);

                entry_index += 1;
            }

            return index, false;
        } else if content.data[index] == #char "[" {
            #if contiguous_memory {
                absolute(result, memory.data, relative).type = .Array;
            } else {
                result.type = .Array;
            }

            success: bool = ---;
            index, success = json_parse_into(content, index, cast(*[..] JsonGeneric) (cast(*u8) result + union_offset), memory, relative, contiguous_memory, keep_strings_in_place);
            return index, success;
        } else if content.data[index] == #char "\"" {
            #if contiguous_memory {
                absolute(result, memory.data, relative).type = .String;
            } else {
                result.type = .String;
            }

            success: bool = ---;
            index, success = json_parse_into(content, index, cast(*string) (cast(*u8) result + union_offset), memory, relative, contiguous_memory, keep_strings_in_place);
            return index, success;
        } else if content.data[index] == #char "n" {
            #if ASSERT {
                assert(is_null(content, index), "Invalid null string.");
            }

            #if contiguous_memory {
                absolute(result, memory.data, relative).type = .Null;
            } else {
                result.type = .Null;
            }

            return index + 4, true;
        } else if content.data[index] == #char "f" {
            #if ASSERT {
                assert(is_false(content, index), "Invalid false string.");
            }

            #if contiguous_memory {
                absolute(result, memory.data, relative).type = .Boolean;
                absolute(result, memory.data, relative).boolean = false;
            } else {
                result.type = .Boolean;
                result.boolean = false;
            }

            return index + 5, true;
        } else if content.data[index] == #char "t" {
            #if ASSERT {
                assert(is_true(content, index), "Invalid true string.");
            }

            #if contiguous_memory {
                absolute(result, memory.data, relative).type = .Boolean;
                absolute(result, memory.data, relative).boolean = true;
            } else {
                result.type = .Boolean;
                result.boolean = true;
            }

            return index + 4, true;
        } else {
            previous_valid_int := true;
            valid_int := true;
            previous_valid_float := true;
            valid_float := true;

            lookahead_index := index;
            while lookahead_index < content.count && (valid_int || valid_float) {
                previous_valid_int = valid_int;
                previous_valid_float = valid_float;
                valid_int = valid_int && is_signed_int_char(content.data[lookahead_index]);
                valid_float = valid_float && is_float_char(content.data[lookahead_index]);

                lookahead_index += 1;
            }

            counted := lookahead_index - index;

            if previous_valid_int && counted > 0 {
                #if contiguous_memory {
                    absolute(result, memory.data, relative).type = .Integer;
                } else {
                    result.type = .Integer;
                }

                success: bool = ---;
                index, success = json_parse_into(content, index, cast(*s64) (cast(*u8) result + union_offset), memory, relative, contiguous_memory, keep_strings_in_place);
                return index, success;
            } else if previous_valid_float && counted > 0 {
                #if contiguous_memory {
                    absolute(result, memory.data, relative).type = .Float;
                } else {
                    result.type = .Float;
                }

                success: bool = ---;
                index, success = json_parse_into(content, index, cast(*float64) (cast(*u8) result + union_offset), memory, relative, contiguous_memory, keep_strings_in_place);
                return index, success;
            }
        }
    }

    return index, false;
}

json_parse_into :: (content: string, index: int, result: *$T, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool #modify modify_require_struct_reject_json_object(T) {
    success: bool;

    #if ASSERT {
        assert(index < content.count && content.data[index] == #char "{", "Missing left bracket.");
    }
    index = trim_right(content, index + 1);

    // check for immediate close
    if index < content.count && content.data[index] == #char "}" {
        return index + 1, true;
    }

    // skip the next quote
    while index < content.count {
        #if ASSERT {
            assert(index < content.count && content.data[index] == #char "\"", "Missing quote.");
        }
        index += 1;

        name, found := get_string_until_closing_quote(content, index);
        if !found {
            return index, false;
        }

        index = trim_right(content, index + name.count + 1);
        #if ASSERT {
            assert(index < content.count && content.data[index] == #char ":", "Missing colon.");
        }

        // now we're starting on the inner value
        index = trim_right(content, index + 1);
        #insert #run get_name_to_parse_string(T);

        index = trim_right(content, index);
        #if ASSERT {
            assert(index < content.count && content.data[index] == #char "," || content.data[index] == #char "}", "Missing comma or right bracket.");
        }
        if index < content.count && content.data[index] == #char "}" {
            return index + 1, true;
        }

        // move on to get the next member
        index = trim_right(content, index + 1);
    }

    return index, false;
}

json_parse_into :: (content: string, index: int, result: *[..] $T, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    success: bool;

    #if ASSERT {
        assert(index < content.count && content.data[index] == #char "[", "Missing left hard bracket.");
    }
    index = trim_right(content, index + 1);

    if index < content.count && content.data[index] == #char "]" {
        return index + 1, true;
    }

    entry_count, found := get_array_entries_until_closing_bracket(content, index);
    if !found {
        return index, false;
    }

    #if contiguous_memory {
    // ill leave allocated as 0 since its not allocating into the array, I guess
        required_bytes := entry_count * size_of(T);
        offset, allocated := allocate(memory, required_bytes, T, initialize = true, resizable_array = true);
        absolute(result, memory.data, relative).data = offset;
        absolute(result, memory.data, relative).count = entry_count;
    } else {
        arr: [..] T;
        array_resize(*arr, entry_count);
        << result = arr;
    }

    for entry_index: 0..entry_count - 1 {
        #if contiguous_memory {
            entry := absolute(result, memory.data, relative).data + entry_index;
        }  else {
            entry := result.data + entry_index;
        }

        index, success = json_parse_into(content, index, entry, memory, true, contiguous_memory, keep_strings_in_place);
        if !success {
            return index, false;
        }
        index = trim_right(content, index);

        #if ASSERT {
            assert(index < content.count && content.data[index] == #char "," || content.data[index] == #char "]", "Missing comma or right hard bracket.");
        }
        if index < content.count && content.data[index] == #char "]" {
            return index + 1, true;
        }
        
        index = trim_right(content, index + 1);
    }

    return index, false;
}

json_parse_into :: (content: string, index: int, result: *[$N] $T, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    success: bool;

    #if ASSERT {
        assert(index < content.count && content.data[index] == #char "[", "Missing left hard bracket.");
    }
    index = trim_right(content, index + 1);

    #if ASSERT {
        entry_count := get_array_entries_until_closing_bracket(content, index);
        assert(entry_count == N, "Incorrect number of fixed array entries.");
    }

    // ill leave allocated as 0 since its not allocating into the array, I guess

    for entry_index: 0..N - 1 {
        // #if contiguous_memory {
        //     entry := absolute(result, memory.data, relative).data + entry_index;
        // } else {
            entry := result.data + entry_index;
        // }

        index, success = json_parse_into(content, index, entry, memory, relative, contiguous_memory, keep_strings_in_place);
        if !success {
            return index, false;
        }
        index = trim_right(content, index);

        #if ASSERT {
            assert(index < content.count && content.data[index] == #char "," || content.data[index] == #char "]", "Missing comma or right hard bracket.");
        }
        if index < content.count && content.data[index] == #char "]" {
            return index + 1, true;
        }
        
        index = trim_right(content, index + 1);
    }

    return index, false;
}

json_parse_into :: (content: string, index: int, result: **$T, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if contiguous_memory {
        if is_null(content, index) {
            return index + 4, true;
        } else {
            offset := allocate(memory, #run size_of(T), T, initialize = true);
            << absolute(result, memory.data, relative) = offset;
            entry: *T = offset;

            success: bool;
            index, success = json_parse_into(content, index, entry, memory, true, contiguous_memory, keep_strings_in_place);
            return index, success;
        }
    } else {
        if is_null(content, index) {
            return index + 4, true;
        } else {
            entry := New(T);
            << result = entry;

            success: bool;
            index, success = json_parse_into(content, index, entry, memory, true, contiguous_memory, keep_strings_in_place);
            return index, success;
        }
    }
}

json_parse_into :: inline (content: string, index: int, result: *$T, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool #modify modify_require_enum(T) {
    EnumType :: #run (t: Type) -> Type {
        enum_info := (cast(*Type_Info_Enum) T).internal_type;
        if enum_info.signed && enum_info.runtime_size == 1 {
            return s8;
        } else if enum_info.signed && enum_info.runtime_size == 2 {
            return s16;
        } else if enum_info.signed && enum_info.runtime_size == 4 {
            return s32;
        } else if enum_info.signed && enum_info.runtime_size == 8 {
            return s64;
        } else if !enum_info.signed && enum_info.runtime_size == 1 {
            return u8;
        } else if !enum_info.signed && enum_info.runtime_size == 2 {
            return u16;
        } else if !enum_info.signed && enum_info.runtime_size == 4 {
            return u32;
        } else {
            return u64;
        }
    }(T);

    index, success := json_parse_into(content, index, cast(*EnumType) result, memory, relative, contiguous_memory, keep_strings_in_place);
    return index, success;
}

json_parse_into :: inline (content: string, index: int, result: *float32, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && is_float_char(content.data[index]), "F32 has invalid characters.");
    }

    first_index := index;
    value_string: string = ---;
    value_string.data = content.data + index;
    while index < content.count && is_float_char(content.data[index]) {
        index += 1;
    }
    value_string.count = index - first_index;

    value, success := string_to_float(value_string);
    if success {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = value;
        } else {
            << result = value;
        }
        return index, true;
    }

    return index, false;
}

json_parse_into :: inline (content: string, index: int, result: *float64, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && is_float_char(content.data[index]), "F64 has invalid characters.");
    }

    first_index := index;
    value_string: string = ---;
    value_string.data = content.data + index;
    while index < content.count && is_float_char(content.data[index]) {
        index += 1;
    }
    value_string.count = index - first_index;

    value, success := string_to_float64(value_string);
    if success {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = value;
        } else {
            << result = value;
        }
        return index, true;
    }

    return index, false;
}

json_parse_into :: inline (content: string, index: int, result: *u8, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && is_unsigned_int_char(content.data[index]), "U8 has invalid characters.");
    }

    first_index := index;
    value_string: string = ---;
    value_string.data = content.data + index;
    while index < content.count && is_unsigned_int_char(content.data[index]) {
        index += 1;
    }
    value_string.count = index - first_index;

    #if ASSERT {
        assert(is_valid_after_number(content, index), "U8 has invalid characters.");
    }

    value, success := string_to_int(value_string, 10, u8);
    if success {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = value;
        } else {
            << result = value;
        }
        return index, true;
    }

    return index, false;
}

json_parse_into :: inline (content: string, index: int, result: *u16, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && is_unsigned_int_char(content.data[index]), "U16 has invalid characters.");
    }

    first_index := index;
    value_string: string = ---;
    value_string.data = content.data + index;
    while index < content.count && is_unsigned_int_char(content.data[index]) {
        index += 1;
    }
    value_string.count = index - first_index;

    #if ASSERT {
        assert(is_valid_after_number(content, index), "U16 has invalid characters.");
    }

    value, success := string_to_int(value_string, 10, u16);
    if success {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = value;
        } else {
            << result = value;
        }
        return index, true;
    }

    return index, false;
}

json_parse_into :: inline (content: string, index: int, result: *u32, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && is_unsigned_int_char(content.data[index]), "U32 has invalid characters.");
    }

    first_index := index;
    value_string: string = ---;
    value_string.data = content.data + index;
    while index < content.count && is_unsigned_int_char(content.data[index]) {
        index += 1;
    }
    value_string.count = index - first_index;

    #if ASSERT {
        assert(is_valid_after_number(content, index), "U32 has invalid characters.");
    }

    value, success := string_to_int(value_string, 10, u32);
    if success {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = value;
        } else {
            << result = value;
        }
        return index, true;
    }

    return index, false;
}

json_parse_into :: inline (content: string, index: int, result: *u64, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && is_unsigned_int_char(content.data[index]), "U64 has invalid characters.");
    }

    first_index := index;
    value_string: string = ---;
    value_string.data = content.data + index;
    while index < content.count && is_unsigned_int_char(content.data[index]) {
        index += 1;
    }
    value_string.count = index - first_index;

    #if ASSERT {
        assert(is_valid_after_number(content, index), "U64 has invalid characters.");
    }

    value, success := string_to_int(value_string, 10, u64);
    if success {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = value;
        } else {
            << result = value;
        }
        return index, true;
    }

    return index, false;
}

json_parse_into :: inline (content: string, index: int, result: *s8, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && is_signed_int_char(content.data[index]), "S8 has invalid characters.");
    }

    first_index := index;
    value_string: string = ---;
    value_string.data = content.data + index;
    while index < content.count && is_signed_int_char(content.data[index]) {
        index += 1;
    }
    value_string.count = index - first_index;

    #if ASSERT {
        assert(is_valid_after_number(content, index), "S8 has invalid characters.");
    }

    value, success := string_to_int(value_string, 10, s8);
    if success {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = value;
        } else {
            << result = value;
        }
        return index, true;
    }

    return index, false;
}

json_parse_into :: inline (content: string, index: int, result: *s16, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && is_signed_int_char(content.data[index]), "S16 has invalid characters.");
    }

    first_index := index;
    value_string: string = ---;
    value_string.data = content.data + index;
    while index < content.count && is_signed_int_char(content.data[index]) {
        index += 1;
    }
    value_string.count = index - first_index;

    #if ASSERT {
        assert(is_valid_after_number(content, index), "S16 has invalid characters.");
    }

    value, success := string_to_int(value_string, 10, s16);
    if success {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = value;
        } else {
            << result = value;
        }
        return index, true;
    }

    return index, false;
}

json_parse_into :: inline (content: string, index: int, result: *s32, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && is_signed_int_char(content.data[index]), "S32 has invalid characters.");
    }

    first_index := index;
    value_string: string = ---;
    value_string.data = content.data + index;
    while index < content.count && is_signed_int_char(content.data[index]) {
        index += 1;
    }
    value_string.count = index - first_index;

    #if ASSERT {
        assert(is_valid_after_number(content, index), "S32 has invalid characters.");
    }

    value, success := string_to_int(value_string, 10, s32);
    if success {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = value;
        } else {
            << result = value;
        }
        return index, true;
    }

    return index, false;
}

json_parse_into :: inline (content: string, index: int, result: *s64, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && is_signed_int_char(content.data[index]), "S64 has invalid characters.");
    }

    first_index := index;
    value_string: string = ---;
    value_string.data = content.data + index;
    while index < content.count && is_signed_int_char(content.data[index]) {
        index += 1;
    }
    value_string.count = index - first_index;

    #if ASSERT {
        assert(is_valid_after_number(content, index), "S64 has invalid characters.");
    }

    value, success := string_to_int(value_string, 10, s64);
    if success {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = value;
        } else {
            << result = value;
        }
        return index, true;
    }

    return index, false;
}

json_parse_into :: inline (content: string, index: int, result: *bool, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(is_true_or_false(content, index), "Bool has invalid characters.");
    }

    if is_true(content, index) {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = true;
        } else {
            << result = true;
        }
        index += 4;
    } else if is_false(content, index) {
        #if contiguous_memory {
            << absolute(result, memory.data, relative) = false;
        } else {
            << result = false;
        }
        index += 5;
    } else {
        return index, false;
    }

    return index, true;
}

json_parse_into :: inline (content: string, index: int, result: *string, memory: *[..] u8, relative: bool, $contiguous_memory: bool, $keep_strings_in_place: bool) -> int, bool {
    #if ASSERT {
        assert(index < content.count && content.data[index] == #char "\"", "Missing quotation.");
    }

    index += 1;
    value, found := get_string_until_closing_quote(content, index);
    if !found {
        return index, false;
    }
    index += value.count + 1;

    #if contiguous_memory {
        #if keep_strings_in_place {
            absolute(result, memory.data, relative).data = value.data;
            absolute(result, memory.data, relative).count = value.count;
        } else {
            offset, allocated := allocate(memory, value.count, u8);
            absolute(result, memory.data, relative).data = offset;
            absolute(result, memory.data, relative).count = value.count;
            memcpy(allocated, value.data, value.count);
        }
    } else {
        #if keep_strings_in_place {
            result.data = value.data;
            result.count = value.count;
        } else {
            << result = copy_string(value);
        }
    }

    return index, true;
}

skip_unknown_type :: inline (content: string, index: int) -> int, bool {
    opened_object_count := 0;
    opened_array_count := 0;
    opened_string := false;

    for lookahead_index: index..content.count - 1 {
        if content.data[lookahead_index] == #char "\"" && content.data[lookahead_index - 1] != #char "\\" {
            opened_string = !opened_string;
        } else if !opened_string {
            if content.data[lookahead_index] == #char "[" {
                opened_array_count += 1;
            } else if content.data[lookahead_index] == #char "]" {
                opened_array_count -= 1;
            } else if content.data[lookahead_index] == #char "{" {
                opened_object_count += 1;
            } else if content.data[lookahead_index] == #char "}" {
                if opened_array_count == 0 && opened_object_count == 0 {
                    return lookahead_index, true;
                }
                opened_object_count -= 1;
            } else if content.data[lookahead_index] == #char "," && opened_array_count == 0 && opened_object_count == 0 {
                return lookahead_index, true;
            }
        }
    }
    
    return index, false;
}

absolute :: inline (pointer: *$T, memory: *u8, relative: bool) -> *T {
    if relative {
        value := cast(int) pointer;
        return cast(*T) (memory + value - 1);
    } else {
        return pointer;
    }
}

allocate :: (memory: *[..] u8, bytes: int, $T: Type, $initialize: bool = true, $resizable_array: bool = false) -> *T, *T {
    required_bytes := memory.count + bytes;
    allocate_bytes: int = ---;

    #if ASM {
        result: s64 = ---;
        required_bytes -= 1;
        // count leading zeros
        #asm {
            lzcnt result, required_bytes;
        }
        allocate_bytes = 1 << (64 - result);
    } else {
        allocate_bytes = memory.allocated;
        while allocate_bytes < required_bytes {
            allocate_bytes += allocate_bytes;
        }
    }

    array_reserve(memory, allocate_bytes);

    relative := cast(*T) (memory.count + 1);
    allocated := cast(*T) (memory.data + memory.count);
    memory.count += bytes;

    #if initialize {
        #if resizable_array {
            ini :: initializer_of(T);
            #if ini {
                entry_size :: #run size_of(T);
                entry_count := bytes / entry_size;
                for 0..entry_count - 1 {
                    inline ini(allocated + it);
                }
            } else {
                memset(allocated, 0, bytes);
            }
        } else {
            ini :: initializer_of(T);
            #if ini {
                inline ini(allocated);
            } else {
                memset(allocated, 0, bytes);
            }
        }
    }

    return cast(*T) relative, cast(*T) allocated;
}

trim_right :: inline (content: string, index: int) -> int {
    char := content.data[index];
    while index < content.count && (char == #char " " || char == #char "\t" || char == #char "\n" || char == #char "\r") {
        index += 1;
        char = content.data[index];
    }

    return index;
}

is_signed_int_char :: inline (char: u8) -> bool {
    valid := false;
    valid = valid || char == #char "-";
    valid = valid || char == #char "0";
    valid = valid || char == #char "1";
    valid = valid || char == #char "2";
    valid = valid || char == #char "3";
    valid = valid || char == #char "4";
    valid = valid || char == #char "5";
    valid = valid || char == #char "6";
    valid = valid || char == #char "7";
    valid = valid || char == #char "8";
    valid = valid || char == #char "9";
    return valid;
}

is_unsigned_int_char :: inline (char: u8) -> bool {
    valid := false;
    valid = valid || char == #char "0";
    valid = valid || char == #char "1";
    valid = valid || char == #char "2";
    valid = valid || char == #char "3";
    valid = valid || char == #char "4";
    valid = valid || char == #char "5";
    valid = valid || char == #char "6";
    valid = valid || char == #char "7";
    valid = valid || char == #char "8";
    valid = valid || char == #char "9";
    return valid;
}

is_float_char :: inline (char: u8) -> bool {
    valid := false;
    valid = valid || char == #char "-";
    valid = valid || char == #char "+";
    valid = valid || char == #char ".";
    valid = valid || char == #char "0";
    valid = valid || char == #char "1";
    valid = valid || char == #char "2";
    valid = valid || char == #char "3";
    valid = valid || char == #char "4";
    valid = valid || char == #char "5";
    valid = valid || char == #char "6";
    valid = valid || char == #char "7";
    valid = valid || char == #char "8";
    valid = valid || char == #char "9";
    valid = valid || char == #char "e";
    valid = valid || char == #char "E";
    return valid;
}

is_true_or_false :: inline (content: string, index: int) -> bool {
    value := false;
    value = value || is_true(content, index);
    value = value || is_false(content, index);
    return value;
}

is_true :: inline (content: string, index: int) -> bool {
    value := index + 4 <= content.count;
    value = value && content.data[index] == #char "t";
    value = value && content.data[index + 1] == #char "r";
    value = value && content.data[index + 2] == #char "u";
    value = value && content.data[index + 3] == #char "e";
    return value;
}

is_false :: inline (content: string, index: int) -> bool {
    value := index + 5 <= content.count;
    value = value && content.data[index] == #char "f";
    value = value && content.data[index + 1] == #char "a";
    value = value && content.data[index + 2] == #char "l";
    value = value && content.data[index + 3] == #char "s";
    value = value && content.data[index + 4] == #char "e";
    return value;
}

is_null :: inline (content: string, index: int) -> bool {
    value := index + 4 <= content.count;
    value = value && content.data[index] == #char "n";
    value = value && content.data[index + 1] == #char "u";
    value = value && content.data[index + 2] == #char "l";
    value = value && content.data[index + 3] == #char "l";
    return value;
}

is_valid_after_number :: inline (content: string, index: int) -> bool {
    valid := false;
    valid = valid || (index < content.count && content.data[index] == #char "]");
    valid = valid || (index < content.count && content.data[index] == #char "}");
    valid = valid || (index < content.count && content.data[index] == #char ",");
    valid = valid || (index < content.count && content.data[index] == #char "\r");
    valid = valid || (index < content.count && content.data[index] == #char "\n");
    valid = valid || (index < content.count && content.data[index] == #char "\t");
    valid = valid || (index < content.count && content.data[index] == #char " ");
    return valid;
}

get_string_until_closing_quote :: inline (content: string, index: int) -> string, bool {
    // this method inherently can't be called until we find the first quote, so we don't have to worry about the -1 index
    // length, found := get_string_length_until_closing_quote(content, index);
    for lookahead: index..content.count - 1 {
        if content.data[lookahead] == #char "\"" && content.data[lookahead - 1] != #char "\\" {
            name: string = ---;
            name.data = content.data + index;
            name.count = lookahead - index;
            return name, true;
        }
    }

    return "", false;
}

get_array_entries_until_closing_bracket :: inline (content: string, index: int) -> int, bool {
    // this method inherently can't be called until we find the first array bracket, so we don't have to worry about the -1 index
    opened_array_count: int;
    opened_object_count: int;
    opened_string: bool;
    top_level_comma_count: int;
    for lookahead_index: index..content.count - 1 {
        if content.data[lookahead_index] == #char "\"" && content.data[lookahead_index - 1] != #char "\\" {
            opened_string = !opened_string;
        } else if !opened_string {
            if content.data[lookahead_index] == #char "[" {
                opened_array_count += 1;
            } else if content.data[lookahead_index] == #char "]" {
                if opened_array_count == 0 {
                    return top_level_comma_count + 1, true;
                }
                opened_array_count -= 1;
            } else if content.data[lookahead_index] == #char "{" {
                opened_object_count += 1;
            } else if content.data[lookahead_index] == #char "}" {
                opened_object_count -= 1;
            } else if content.data[lookahead_index] == #char "," && opened_array_count == 0 && opened_object_count == 0 {
                top_level_comma_count += 1;
            }
        }
    }

    return 0, false;
}

get_object_entries_until_closing_bracket :: inline (content: string, index: int) -> int, bool {
    // this method inherently can't be called until we find the first array bracket, so we don't have to worry about the -1 index
    opened_array_count: int;
    opened_object_count: int;
    opened_string: bool;
    top_level_comma_count: int;
    for lookahead_index: index..content.count - 1 {
        if content.data[lookahead_index] == #char "\"" && content.data[lookahead_index - 1] != #char "\\" {
            opened_string = !opened_string;
        } else if !opened_string {
            if content.data[lookahead_index] == #char "[" {
                opened_array_count += 1;
            } else if content.data[lookahead_index] == #char "]" {
                opened_array_count -= 1;
            } else if content.data[lookahead_index] == #char "{" {
                opened_object_count += 1;
            } else if content.data[lookahead_index] == #char "}" {
                if opened_object_count == 0 {
                    return top_level_comma_count + 1, true;
                }
                opened_object_count -= 1;
            } else if content.data[lookahead_index] == #char "," && opened_array_count == 0 && opened_object_count == 0 {
                top_level_comma_count += 1;
            }
        }
    }

    return 0, false;
}

get_member_offset :: (t: Type, member_name: string) -> int {
    info := cast(*Type_Info_Struct) t;
    assert(info.type == .STRUCT, "Can only get member offset for a struct.");

    for member: info.members {
        if member.name == member_name {
            return member.offset_in_bytes;
        }
    }

    assert(info.type == .STRUCT, "The member must exist.");
    return 0;
}

get_name_to_parse_string :: (t: Type) -> string {
    builder: String_Builder;

    info := cast(*Type_Info_Struct) t;
    assert(info.type == .STRUCT, "Cannot get member name type info of non-struct.");

    valid_members: int;
    for member: info.members {
        if member.offset_into_constant_storage >= 0 {
            continue;
        }

        if ignore_member(member.notes) {
            continue;
        }

        valid_members += 1;
    }

    current_member: int;
    for member: info.members {
        if member.offset_into_constant_storage >= 0 {
            continue;
        }

        if ignore_member(member.notes) {
            continue;
        }

        member_name := member.name;
        json_name := get_json_name(member.name, member.notes);


        // TODO would generating a switch statement be better performance? need to test
        append(*builder, "if name == \"");
        append(*builder, json_name);
        append(*builder, "\" {\n");
        append(*builder, "InnerType :: #run type_of(result.");
        append(*builder, member_name);
        append(*builder, ");\n");
        // cast(*InnerType) ((cast(*u8) result) + member.offset_in_bytes)
        append(*builder, "index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + ");
        append(*builder, tprint("%", member.offset_in_bytes));
        append(*builder, "), memory, relative, contiguous_memory, keep_strings_in_place);\n");
        append(*builder, "if !success {\n");
        append(*builder, "return index, false;\n");
        append(*builder, "}\n");
        append(*builder, "}");

        if current_member < valid_members - 1 {
            append(*builder, " else ");
        }

        current_member += 1;
    }

    if valid_members > 0 {
        append(*builder, " else {\n");
        append(*builder, "index, success = skip_unknown_type(content, index);\n");
        append(*builder, "if !success {\n");
        append(*builder, "return index, false;\n");
        append(*builder, "}\n");
        append(*builder, "}\n");
    }

    return builder_to_string(*builder);
}

get_pointer_update_string :: (t: Type, top_level_name: string, keep_strings_in_place: bool) -> string {
    info := cast(*Type_Info) t;

    get_child :: (t: Type, top_level_name: string, keep_strings_in_place: bool) -> string {
        info := cast(*Type_Info) t;
        array_info := cast(*Type_Info_Array) info;

        builder: String_Builder;

        if info.type == .STRUCT {
            if t == JsonGeneric {
                append(*builder, "json_object_update_pointers(*");
                append(*builder, top_level_name);
                append(*builder, ", pointer_offset);\n");
            } else {
                struct_info := cast(*Type_Info_Struct) info;

                if struct_info.textual_flags & .UNION {
                    assert(false, "Cannot process a struct with a union.");
                }

                for member: struct_info.members {
                    if member.offset_into_constant_storage >= 0 {
                        continue;
                    }

                    append(*builder, get_child(<< cast(*Type) *member.type, tprint("%.%", top_level_name, member.name), keep_strings_in_place));
                }
            }
        } else if info.type == .POINTER {
            pointer_info := cast(*Type_Info_Pointer) info;

            append(*builder, "if ");
            append(*builder, top_level_name);
            append(*builder, " {\n");

            append(*builder, top_level_name);
            append(*builder, " = xx ((cast(*u8) ");
            append(*builder, top_level_name);
            append(*builder, ") + pointer_offset);\n");

            append(*builder, get_child(<< cast(*Type) *pointer_info.pointer_to, top_level_name, keep_strings_in_place));
            append(*builder, "}\n");
        } else if info.type == .ARRAY && array_info.array_type == .RESIZABLE {
            append(*builder, "if ");
            append(*builder, top_level_name);
            append(*builder, ".data {\n");

            append(*builder, top_level_name);
            append(*builder, ".data = xx ((cast(*u8) ");
            append(*builder, top_level_name);
            append(*builder, ".data) + pointer_offset);\n");

            // check if there is anything to do for the array element type, and if so loop it
            if get_child(<< cast(*Type) *array_info.element_type, "", keep_strings_in_place) {
                iterator_name := tprint("%_iterator", replace(replace(replace(top_level_name, ".", "_"), "[", "_"), "]", "_"));
                append(*builder, "for ");
                append(*builder, iterator_name);
                append(*builder, ": 0..");
                append(*builder, top_level_name);
                append(*builder, ".count - 1 {\n");
                append(*builder, get_child(<< cast(*Type) *array_info.element_type, tprint("%.data[%]", top_level_name, iterator_name), keep_strings_in_place));
                append(*builder, "}\n");
            }

            append(*builder, "}\n");
        } else if info.type == .ARRAY && array_info.array_type == .FIXED {
            for i: 0..array_info.array_count - 1 {
                append(*builder, get_child(<< cast(*Type) *array_info.element_type, tprint("%.data[%]", top_level_name, i), keep_strings_in_place));
            }
        } else if info.type == .STRING && !keep_strings_in_place {
            append(*builder, "if ");
            append(*builder, top_level_name);
            append(*builder, ".data {\n");

            append(*builder, top_level_name);
            append(*builder, ".data = xx ((cast(*u8) ");
            append(*builder, top_level_name);
            append(*builder, ".data) + pointer_offset);\n");
            
            append(*builder, "}\n");
        }

        return builder_to_string(*builder);
    }

    return get_child(t, top_level_name, keep_strings_in_place);
}

#import "Basic";
#import "String";
