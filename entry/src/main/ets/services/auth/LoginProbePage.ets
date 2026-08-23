import { OfficialLoginPage } from './OfficialLoginPage';

@Component
export struct LoginProbePage {
  onClose: () => void = () => {};

  build() {
    OfficialLoginPage({ onClose: this.onClose, showDiagnostics: true })
  }
}
