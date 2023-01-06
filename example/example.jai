main :: () {
    // TODO once floats work perfectly in sync with javascript the tests can be improved by removing whitespaces and comparing strings to the original json

    #insert #run () -> string {
        files := file_list("tests");

        builder: String_Builder;

        for file: files {
            if !ends_with(file, ".jai") {
                continue;
            }

            file_contents := read_entire_file(file);
            append(*builder, tprint(#string DONE
            {
                %
                
                print("Testing %.\n\n");

                start := get_time() * 1000;
                result, memory, success := json_parse(JSON_STRING, JsonType, contiguous_memory = true);
                end := get_time() * 1000;
                defer free(memory);
                if success {
                    print("Succeeded in parsing json.\n");
                    print("Took %% milliseconds.\n\n", end - start);

                    if JSON_STRING.count < 1000 {
                        print("Result:\n");
                        print_anything(result);
                    }

                    json := json_write(result);
                    defer free(json);

                    if JSON_STRING.count < 1000 {
                        print("Written:\n");
                        print_anything(json);
                    }

                    result2, memory2, success2 := json_parse(json, JsonType);
                    defer free(memory2);

                    json_equal := json_write(result2);
                    defer free(json_equal);

                    if json == json_equal {
                        print("Successfully wrote the same json twice.\n\n");
                    } else {
                        print("Failed to write the same json twice.\n\n", to_standard_error = true);
                    }
                } else {
                    print("Failed to parse.\n", to_standard_error = true);
                }

                print("---\n\n");
            }
            DONE, file_contents, file));
        }

        return builder_to_string(*builder);
    }();
}

print_anything :: (value: $T, name: string = "", depth: int = 0) {
    #if #run (cast(*Type_Info) T).type == .POINTER {
        if value {
            print_anything(<< value, name, depth);
            return;
        }
    }

    for i: 0..depth - 1 {
        print("\t");
    }

    if name {
        print("% = %\n", name, value);
    } else {
        print("%\n", value);
    }

    #insert #run (t: Type) -> string {
        builder: String_Builder;

        struct_info := cast(*Type_Info_Struct) t;
        if t == JsonObject {
            append(*builder, #string DONE
            if value.type == .Object {
                for entry: value.object.entries {
                    print_anything(entry.value, entry.name, depth + 1);
                }
            } else if value.type == .Array {
                for i: 0..value.array.entries.count - 1 {
                    print_anything(value.array.entries[i], tprint("value[%]", i), depth + 1);
                }
            } else if value.type == .Integer {
                print_anything(value.integer, name, depth);
            } else if value.type == .Float {
                print_anything(value.number, name, depth);
            } else if value.type == .Boolean {
                print_anything(value.boolean, name, depth);
            } else if value.type == .String {
                print_anything(value.str, name, depth);
            } else if value.type == .Null {
                print_anything(cast(*void) null, name, depth);
            }
            DONE);
        } else if struct_info.type == .STRUCT {
            for member: struct_info.members {
                if member.offset_into_constant_storage >= 0 {
                    continue;
                }

                if member.type.type == .POINTER {
                    append(*builder, "if value.");
                    append(*builder, member.name);
                    append(*builder, " {\n");
                    append(*builder, "print_anything(");
                    append(*builder, "<< value.");
                    append(*builder, member.name);
                    append(*builder, ", \"");
                    append(*builder, member.name);
                    append(*builder, "\", depth + 1);\n");
                    append(*builder, "}\n");
                } else {
                    append(*builder, "print_anything(");
                    append(*builder, "value.");
                    append(*builder, member.name);
                    append(*builder, ", \"");
                    append(*builder, member.name);
                    append(*builder, "\", depth + 1);\n");
                }
            }
        } else if struct_info.type == .ARRAY {
            append(*builder, "for i: 0..value.count - 1 {\n");
            append(*builder, "print_anything(value.data[i], tprint(\"value[%]\", i), depth + 1);\n");
            append(*builder, "};\n");
        }

        return builder_to_string(*builder);
    }(T);

    if depth == 0 {
        print("\n");
    }
}

#import "ContiguousJsonJai"(ASSERT = false);
#import "Basic";
#import "File_Utilities";
#import "File";
#import "String";