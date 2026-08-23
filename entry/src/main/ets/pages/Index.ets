import { P0ProbePage } from '../views/pages/P0ProbePage';

@Entry
@Component
struct Index {
  build() {
    Stack() {
      P0ProbePage()
    }
    .width('100%')
    .height('100%')
  }
}
