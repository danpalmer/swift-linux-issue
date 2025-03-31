To run on macOS, successfully:

```
swift run
```

To run on Linux, unsuccessfully:

```
docker run --rm -v $(pwd):/code -w /code swift:6 swift run
```
