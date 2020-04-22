package objects

import (
    "distributed-object-storage/api_server/locate"
    "distributed-object-storage/src/utils"
    "fmt"
    "io"
    "net/http"
    "net/url"
)

func storeObject(reader io.Reader, hash string, size int64) (statusCode int, err error) {
    escapedHash := url.PathEscape(hash)
    // 若是对象的内容数据已存在，则不用重复上传，否则将对象数据保存到临时缓存中等待校验
    if locate.Exist(escapedHash) {
        return http.StatusOK, nil
    }
    // 保存对象数据到临时缓存
    stream, err := putStream(escapedHash, size)
    if err != nil {
        return http.StatusInternalServerError, err
    }

    // 读取的同时进行数据写入
    // 使用r进行读数据的同时，stream会调用Write()方法进行数据写入
    r := io.TeeReader(reader, stream)
    actualHash := utils.CalculateHash(r)
    if actualHash != hash {
        stream.Commit(false)
        err = fmt.Errorf("Error: object hash value is not match, actualHash=[%s], expectedHash=[%s]\n", actualHash, hash)
        return http.StatusBadRequest, err
    }
    stream.Commit(true)

    return http.StatusOK, nil
}
