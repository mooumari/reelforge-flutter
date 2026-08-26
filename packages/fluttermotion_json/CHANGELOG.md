## 0.1.0

- Initial release: a JSON document format for FlutterMotion compositions and
  the runtime that builds it.
- Storyboard (`scenes`) and single-tree (`root`) documents.
- Around thirty node types covering layout primitives, media and the kit.
- `{{ path }}` data binding with five display filters, and `repeat` for both
  widget lists and chart data.
- Animatable numbers anywhere a number is expected: literals, keyframe tracks
  and springs, measured against the enclosing sequence and stagger.
- Palette roles and hex colours, so a document stays themeable.
- Validation that reports every problem at once with a JSON path, and refuses
  a `src` that leaves the project directory.
