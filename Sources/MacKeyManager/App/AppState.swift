import SwiftUI
import MacKeyManagerLib

@Observable
final class AppState {
    let zshrcService: ZshrcService
    let catalogService: CatalogService
    let fileWatcher: FileWatcherService
    let keyVaultService: KeyVaultService
    let envVarListVM: EnvVarListViewModel
    let projectVM: ProjectViewModel

    init() {
        let zshrc = ZshrcService()
        let catalog = CatalogService()
        let watcher = FileWatcherService()
        let vault = KeyVaultService()
        let projectVM = ProjectViewModel()
        let envVarListVM = EnvVarListViewModel(zshrcService: zshrc, catalogService: catalog, keyVaultService: vault)

        self.zshrcService = zshrc
        self.catalogService = catalog
        self.fileWatcher = watcher
        self.keyVaultService = vault
        self.projectVM = projectVM
        self.envVarListVM = envVarListVM

        // Set up file watcher callback
        watcher.onFileChanged = { [weak envVarListVM] url in
            envVarListVM?.reloadActiveSource()
        }

        // Start watching .zshrc
        watcher.watch(url: zshrc.fileURL)

        // Load vault
        vault.load()

        // Load global variables on startup
        envVarListVM.loadGlobalVariables()
    }
}
