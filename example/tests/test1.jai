
JSON_STRING :: #string DONE
{
    "key2": 0.5,
    "key1": "hey",
    "key3": [0.4, 0.6, 0.8, 1.0],
    "key4": {
        "key5": 2.0,
        "key6": "lol"
    },
    "key8": 1.5,
    "enum_val": 2
}
DONE

JsonType :: struct {
    Key4 :: struct {
        key5: float;
        key6: *string;
    };

    EnumType :: enum s32 {
        Hey :: 1;
        No :: 2;
    }

    // optional
    key1: *string;
    // required
    key2: float;
    // optional
    key3: *[..] float;
    // required
    key4: Key4;
    // optional
    key7: *float;
    // optional
    key8: *float;
    enum_val: EnumType;
}