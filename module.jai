#module_parameters(ASM := true);
#module_parameters(VALIDATE := true);

json_parse :: (content: string, $T: Type) -> T, *u8, bool {
    result: T;
    memory: [..] u8;
    if json_parse(content, 0, *result, *memory) {
        return result, memory.data, true;
    } else {
        return result, memory.data, false;
    }
}

#scope_file

MemberTypeInfo :: struct {
    name: string;
    info: *Type_Info;
}

json_parse_into :: (content: string, index: int, result: *T, memory: *[..] u8) -> int, bool #modify modify_require_struct(T) {
    index = trim_right(content, index);
    success: bool;

    #if #run type_info(T).type == .STRUCT {
        #if VALIDATE {
            assert(content.data[index] == #char "{", "Missing left bracket.");
        }

        index = trim_right(content, index + 1);
        index, success = json_parse_object_into(content, index, result, memory);
    } else #if #run type_info(T).type == .ARRAY {
        #if VALIDATE {
            assert(content.data[index] == #char "[", "Missing left hard bracket.");
        }

        index = trim_right(content, index + 1);
        index, success = json_parse_array_into(content, index, result, memory);
    } else #if #run type_info(T).type == .POINTER {
        
    } else #if #run type_info(T).type == .FLOAT {
        
    } else #if #run type_info(T).type == .INTEGER {
        
    } else #if #run type_info(T).type == .BOOL {
        
    } else #if #run type_info(T).type == .STRING {
        
    } else {
        return 0, false;
    }

    return index, success;
}

json_parse_object_into :: (content: string, index: int, result: *T, memory: *[..] u8) -> int, bool #modify modify_require_struct(T) {
    success: bool;

    // skip the next quote
    while content.data[index] != #char "}" {
        #if VALIDATE {
            assert(content.data[index] == #char "\"", "Missing quote.");
        }
        index += 1;

        name := get_name_until_closing_quote(content, index);
        index += name.count + 1;

        index = trim_right(content, index);
        #if VALIDATE {
            assert(content.data[index] == #char ":", "Missing colon.");
        }
        index += 1;

        // now we're starting on the inner value
        index = trim_right(content, index);
        #insert #run get_name_to_parse_string(T);

        index = trim_right(content, index);
    }

    return index, success;
}

json_parse_array_into :: (content: string, index: int, result: *[..] T, memory: *[..] u8) -> int, bool {
    
}

json_parse_array_into :: (content: string, index: int, result: *[$N] T, memory: *[..] u8) -> int, bool {
    
}

json_parse_pointer_into :: (content: string, index: int, result: **T, memory: *[..] u8) -> int, bool {

}

json_parse_float_into :: (content: string, index: int, result: *float, memory: *[..] u8) -> int, bool {

}

json_parse_int_into :: (content: string, index: int, result: *int, memory: *[..] u8) -> int, bool {

}

json_parse_bool_into :: (content: string, index: int, result: *bool, memory: *[..] u8) -> int, bool {

}

json_parse_string_into :: (content: string, index: int, result: *string, memory: *[..] u8) -> int, bool {

}

allocate :: (memory: *[..] u8, bytes: int) -> *u8 {
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

    array_reserve(*memory, allocate_bytes);

    allocated := memory.data + memory.count;
    memory.count += bytes;

    return allocated;
}

trim_right :: inline (content: string, index: int) -> *u8 {
    char := content.data[index];
    while char == #char " " || char == #char "\t" || char == #char "\n" || char == #char "\r" {
        index += 1;
        char = content.data[index];
    }
}

get_name_to_parse_string :: (T: Type) -> string {
    builder: String_Builder;

    info := cast(*Type_Info_Struct) T;
    assert(info.type == .STRUCT, "Cannot get member name type info of non-struct.");

    valid_members: int;
    for member: info.members {
        if member.offset_into_constant_storage >= 0 {
            continue;
        }

        valid_members += 1;
    }

    current_member: int;
    for member: info.members {
        if member.offset_into_constant_storage >= 0 {
            continue;
        }

        // TODO would generating a switch statement be better performance? need to test
        append(*builder, "if name == \"");
        append(*builder, member.name);
        append(*builder, "\" {\n");
        append(*builder, "index, success = json_parse_into(content, index, *result.");
        append(*builder, member.name);
        append(*builder, ", memory);\n");
        append(*builder, "}");

        if current_member < valid_members - 1 {
            append(*builder, " else ");
        }

        current_member += 1;
    }

    return builder_to_string(*builder);
}

get_name_until_closing_quote :: inline (content: string, index: int) -> string {
    name: string = ---;
    name.data = content.data + index;
    name.count = 0;
    while content.data[index + name.count] != #char "\"" {
        name.count += 1;
    }

    return name;
}

modify_require_struct :: ($T: Type) #expand {
    `info :: cast(*Type_Info) T;
    `return info.type == .STRUCT;
}

#import "Basic";
#import "String_Builder";
