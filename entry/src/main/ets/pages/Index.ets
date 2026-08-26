import { RootTabPage } from '../views/pages/RootTabPage';

@Entry
@Component
struct Index {
  build() {
    Stack() {
      RootTabPage()
    }
    .width('100%')
    .height('100%')
  }
}
