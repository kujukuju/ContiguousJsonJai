
JSON_STRING :: #string DONE
{
    "key1": 0.1,
    "key2": 0.2,
}
DONE

JsonType :: struct {
    key1: float; @jsonignore
    key2: float;
}