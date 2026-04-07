#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QResource>

int main(int argc, char *argv[])
{
    // Allow XMLHttpRequest to read local files for image encoding
    qputenv("QML_XHR_ALLOW_FILE_READ", "1");

    QGuiApplication app(argc, argv);
    app.setOrganizationName("SailorAI");
    app.setApplicationName("SailorAI API Abstraction - Desktop PoC");

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));

    return app.exec();
}