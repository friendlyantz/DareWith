# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@rails/ujs", to: "https://ga.jspm.io/npm:@rails/ujs@7.1.2/app/assets/javascripts/rails-ujs.esm.js"
pin "credential"
pin "messenger"
pin "native_share"

pin "@material/list", to: "https://ga.jspm.io/npm:@material/list@4.0.0/dist/mdc.list.js"
pin "@material/menu", to: "https://ga.jspm.io/npm:@material/menu@4.0.0/dist/mdc.menu.js"
pin "@material/snackbar", to: "https://ga.jspm.io/npm:@material/snackbar@4.0.0/dist/mdc.snackbar.js"
pin "@material/textfield", to: "https://ga.jspm.io/npm:@material/textfield@4.0.0/dist/mdc.textfield.js"
pin "@material/top-app-bar", to: "https://ga.jspm.io/npm:@material/top-app-bar@4.0.0/dist/mdc.topAppBar.js"
pin "@hotwired/hotwire-native-bridge", to: "@hotwired--hotwire-native-bridge.js" # @1.2.2
