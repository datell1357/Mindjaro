# MaeumjaroCore 현지화 리소스

각 타깃의 `Resources/Localizable.xcstrings`가 문구의 원본이다.
현재 SwiftPM CLI는 String Catalog를 컴파일하지 않으므로, 생성된
`ko.lproj/Localizable.strings`를 함께 버전 관리한다. SwiftPM과 Xcode는
이 생성 파일을 사용하며 카탈로그는 패키지 리소스 처리에서 제외해 중복 출력을 방지한다.

패키지 디렉터리에서 카탈로그 변경 후 재생성한다. 생성 파일을 직접 편집하지 않는다.

```sh
./scripts/compile_localizations.sh
```

테스트 전에 원본과 생성 파일의 일치를 검사한다. 불일치하면 종료 코드 1을 반환한다.

```sh
./scripts/compile_localizations.sh --check
swift test
```

스크립트는 임시 컴파일 결과를 삭제하지 않고 보관 경로를 출력한다.
