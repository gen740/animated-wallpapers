# Animated Wallpapers

Swift / AppKit で動く macOS 向けの動く壁紙と、ブラウザで静止画を生成する HTML 版。

| アプリ | 内容 | メニューバー |
| --- | --- | --- |
| [Penrose Nocturne](docs/penrose.md) | 暗い青緑と金色のペンローズ模様。ポインタに反応して光る | ◇ |
| [Life — Matte Gold](docs/life.md) | 黒と落ち着いた金色のライフゲーム。クリックでセルを反転 | ▦ |

## 必要な環境

- macOS 13 以降
- Swift 5.9 以降を含む Xcode または Command Line Tools

外部パッケージは使っていません。

## ビルド・起動

```sh
git clone https://github.com/gen740/animated-wallpapers.git
cd animated-wallpapers
./scripts/build-app.sh
open "dist/Penrose Nocturne.app"
```

`./scripts/build-app.sh penrose` または `./scripts/build-app.sh life` で片方だけビルドできます。Life を起動する場合は `open "dist/Life Matte Gold.app"` を実行します。2 つを同時に起動すると背景が重なるため、どちらか一方を使ってください。

Swift Package として直接起動することもできます。

```sh
swift run PenroseWallpaper
# または
swift run LifeWallpaper
```

アプリは Dock に表示されません。メニューバーから一時停止・終了できます。各ディスプレイに背景用のウィンドウを表示し、システムの壁紙設定は変更しません。終了すると元の壁紙が見えます。生成したアプリは署名・公証していません。

ログイン時に起動する場合は、生成されたアプリを macOS の「システム設定 → 一般 → ログイン項目」に登録してください。

## HTML 版

[`web/quasicrystal-wallpaper.html`](web/quasicrystal-wallpaper.html) をブラウザで開くと、ペンローズ模様の静止画を表示し、8K PNG として保存できます。サーバーやインストールは不要です。

## マウス入力とデータの扱い

Penrose はポインタの位置を使い、Life は他のアプリ上での左クリックも監視して盤面に反映します。ソースには入力の記録・ファイルへの保存・ネットワーク送信処理はありません。Life のクリック反応が動かない場合の確認事項は [Life の説明](docs/life.md) を参照してください。

## 構成

```text
Sources/                 macOS アプリのソース
  PenroseWallpaper/
  LifeWallpaper/
scripts/build-app.sh     アプリバンドルの生成
docs/                    各アプリの説明
web/                     ブラウザ向けの静止画生成
dist/                    生成した .app（Git 管理外）
```

## ライセンス

[MIT License](LICENSE)
