main :: () {
    result1, success1 := json_parse(JSON_STRING1, JsonType1, #run json_buffer_size(JsonType1));
    if success1 {
        prints_value1(result1);
    } else {
        print("Unsuccessful 1.\n");
    } 

    result2, success2 := json_parse(JSON_STRING2, [..] JsonType2Entry, JsonType2Entry, #run json_buffer_size(JsonType2Entry));
    if success2 {
        prints_value2(result2);
    } else {
        print("Unsuccessful 2.\n");
    }

    result3, success3 := json_parse(JSON_STRING3, [2] JsonType3Entry, 2, JsonType3Entry, #run json_buffer_size(JsonType3Entry));
    if success3 {
        prints_value3(result3);
    } else {
        print("Unsuccessful 2.\n");
    }
}

prints_value1 :: (value: JsonType1) {
    print("value1 %\n", value);
}

ENTRY2_SIZE :: #run json_buffer_size(JsonType2Entry);
prints_value2 :: (value: [..] ContiguousJson(JsonType2Entry, ENTRY2_SIZE)) {
    print("value2 %\n", value);
}

ENTRY3_SIZE :: #run json_buffer_size(JsonType3Entry);
prints_value3 :: (value: [2] ContiguousJson(JsonType3Entry, ENTRY3_SIZE)) {
    print("value3 %\n", value);
}

JsonType1 :: struct {
    Key4 :: struct {
        key5: float;
        key6: *string;
    };

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
}

JsonType2Entry :: struct {
    // required
    number: int;
    // optional
    value: *float;
    // required
    other_number: u32;
    // required
    fourth_number: int;
}

JsonType3Entry :: struct {
    // required
    number: int;
    // optional
    value: *float;
    // required
    other_number: u32;
    // required
    fourth_number: int;
}

JSON_STRING1 :: #string DONE
{
	"key2": 0.5,
	"key1": "hey",
	"key3": [0.4, 0.6, 0.8, 1.0],
	"key4": {
		"key5": 2.0,
		"key6": "lol"
	},
	"key8": 1.5
}
DONE

JSON_STRING2 :: #string DONE
[
    {
        "number": -4,
        "value": 0.5,
        "other_number: 4,
        "fourth_number": 400
    }, {
        "number": -5,
        "other_number: 5,
        "fourth_number": 500
    }
]
DONE

JSON_STRING3 :: #string DONE
[
    {
        "number": -4,
        "value": 0.5,
        "other_number: 4,
        "fourth_number": 400
    }, {
        "number": -5,
        "other_number: 5,
        "fourth_number": 500
    }
]
DONE

#import "ContiguousJsonJai";
#import "Basic";
