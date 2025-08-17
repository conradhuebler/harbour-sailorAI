import QtQuick 2.0
import Nemo.Configuration 1.0

ConfigurationValue {
    property string provider: ""
    key: "/SailorAI/config_" + provider
    defaultValue: ""
}