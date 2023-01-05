
JSON_STRING :: #string DONE
[
    {
        "number": -4,
        "value": 0.5,
        "other_number": 4,
        "fourth_number": 400
    }, {
        "number": -5,
        "other_number": 5,
        "fourth_number": 500
    }
]
DONE

JsonType :: [..] struct {
    // required
    number: int;
    // optional
    value: *float;
    // required
    other_number: u32;
    // required
    fourth_number: int;
};