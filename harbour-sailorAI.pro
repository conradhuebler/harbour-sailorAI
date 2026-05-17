# NOTICE:
#
# Application name defined in TARGET has a corresponding QML filename.
# If name defined in TARGET is changed, the following needs to be done
# to match new name:
#   - corresponding QML filename must be changed
#   - desktop icon filename must be changed
#   - desktop filename must be changed
#   - icon definition filename in desktop file must be changed
#   - translation filenames have to be changed

# The name of your application
TARGET = harbour-sailorAI

CONFIG += sailfishapp_qml

DISTFILES += qml/harbour-sailorAI.qml \
    qml/cover/CoverPage.qml \
    qml/pages/MainPage.qml \
    qml/pages/SettingsPage.qml \
    qml/dialogs/RenameDialog.qml \
    qml/js/LLMApi.js \
    rpm/README \
    rpm/harbour-sailorAI.changes.in \
    rpm/harbour-sailorAI.changes.run.in \
    rpm/harbour-sailorAI.spec \
    rpm/harbour-sailorAI.yaml \
    harbour-sailorAI.desktop

# Copy API abstraction layer JS files from source to qml/js/ at build time
API_JS_SRC = $$PWD/api-abstraction-layer/src/js
API_JS_DEST = $$PWD/qml/js
API_JS_FILES = ApiAbstraction.js AliasManager.js EndpointBuilder.js ConfigLoader.js

for(file, API_JS_FILES) {
    src = $$API_JS_SRC/$$file
    dst = $$API_JS_DEST/$$file
    QMAKE_POST_LINK += $$QMAKE_COPY $$shell_path($$src) $$shell_path($$dst) $$escape_expand(\\n\\t)
}

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

# to disable building translations every time, comment out the
# following CONFIG line
CONFIG += sailfishapp_i18n

# German translation is enabled as an example. If you aren't
# planning to localize your app, remember to comment out the
# following TRANSLATIONS line. And also do not forget to
# modify the localized app name in the the .desktop file.
TRANSLATIONS += translations/harbour-sailorAI-de.ts \
                translations/harbour-sailorAI-fr.ts \
                translations/harbour-sailorAI-fi.ts

dbus_service.files = dbus/harbour.sailorAI.service
dbus_service.path = /usr/share/dbus-1/services
INSTALLS += dbus_service