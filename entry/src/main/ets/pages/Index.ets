import { RootPage } from '../views/pages/RootPage';

@Entry
@Component
struct Index {
  build() {
    Stack() {
      RootPage()
    }
    .width('100%')
    .height('100%')
  }
}
