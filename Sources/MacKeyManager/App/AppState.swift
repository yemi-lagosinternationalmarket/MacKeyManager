import SwiftUI
import MacKeyManagerLib

@Observable
final class AppState {
    let zshrcService: ZshrcService
    let catalogService: CatalogService
    let fileWatcher: FileWatcherService
    let envVarListVM: EnvVarListViewModel
    let projectVM: ProjectViewModel

    init() {
        let zshrc = ZshrcService()
        let catalog = CatalogService()
        let watcher = FileWatcherService()
        let projectVM = ProjectViewModel()
        let envVarListVM = EnvVarListViewModel(zshrcService: zshrc, catalogService: catalog)

        self.zshrcService = zshrc
        self.catalogService = catalog
        self.fileWatcher = watcher
        self.projectVM = projectVM
        self.envVarListVM = envVarListVM

        // Set up file watcher callback
        watcher.onFileChanged = { [weak envVarListVM] url in
            envVarListVM?.reloadActiveSource()
        }

        // Start watching .zshrc
        watcher.watch(url: zshrc.fileURL)

        // Load global variables on startup
        envVarListVM.loadGlobalVariables()
    }
}
