
JSON_STRING :: #string DONE
[
    {
        "number": -4,
        "value": 0.5,
        "other_number": 4,
        "fourth_number": 400,
        "context": "context one!"
    }, {
        "number": -5,
        "other_number": 5,
        "fourth_number": 500,
        "context": "context two???\" I escaped a quote"
    }
]
DONE

JsonType :: [2] struct {
    // required
    what: int; @json(number)
    // optional
    value: *float;
    // required
    other_number: u32;
    // required
    fourth_number: int;
    test: string; @json(context)
};