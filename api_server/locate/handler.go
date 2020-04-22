package locate

import (
    "distributed-object-storage/src/err_utils"
    "distributed-object-storage/src/utils"
    "encoding/json"
    "net/http"
)

func Handler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }

    location := Locate(utils.GetObjectName(r.URL.EscapedPath()))
    if location == "" {
        w.WriteHeader(http.StatusNotFound)
        return
    }

    locationJson, err := json.Marshal(location)
    err_utils.PanicNonNilError(err)
    w.Write(locationJson)
}
