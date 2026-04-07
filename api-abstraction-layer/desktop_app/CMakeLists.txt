cmake_minimum_required(VERSION 3.16)
project(SailorAIDesktopPoC LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt5 COMPONENTS Quick Core QuickControls2 REQUIRED)

set(SOURCES main.cpp)
set(RESOURCES qml.qrc)

add_executable(${PROJECT_NAME} ${SOURCES} ${RESOURCES})
target_link_libraries(${PROJECT_NAME} PRIVATE Qt5::Quick Qt5::Core Qt5::QuickControls2)