# Parse-Utils

## setup

### env file

実行環境を判定するためのenvファイルの準備が必須。

なかった場合はBabyryUtils::Commonでエラーとなる。

name         | value
:------------|:-------------------------------
ファイル名   | /etc/.secret/babyry_env
許可するenv  | production, development, local

#### 例
```
hiratamotoi:cloud hiratamotoi$ cat /etc/.secret/babyry_env
local
```
