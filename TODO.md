# MacPie Development TODOs

## ✅ Completed Tasks

1. **`update-software-panel`** - Update software panel to match Figma design with dark theme ✅ **COMPLETED**
2. **`implement-pie-center-layout`** - Implement the center pie configuration layout ✅ **COMPLETED**
3. **`implement-commands-panel`** - Implement right commands panel with search and command cards ✅ **COMPLETED**
4. **`update-header-tabs`** - Update header with proper General and Pie Configuration tabs ✅ **COMPLETED**
5. **`fix-compilation-errors`** - Fix compilation errors in PieConfigurationView ✅ **COMPLETED**
6. **`test-figma-ui`** - Build and test the Figma-based UI implementation ✅ **COMPLETED**
7. **`fix-ui-scaling`** - Fix UI scaling and layout to match Figma design exactly ✅ **COMPLETED**
8. **`fix-pie-menu-icons`** - Fix pie menu to show assigned icons when hotkey is pressed ✅ **COMPLETED**
9. **`implement-splash-screen`** - Add splash screen modal with logo, name, version, and loading indicator ✅ **COMPLETED**

## 🔄 In Progress Tasks

None currently.

## ⏳ Pending Tasks

1. **`implement-drag-drop-fixes`** - Ensure drag and drop works properly from command list to pie
2. **`fix-pie-hover-detection`** - Fix hover detection issues in pie configuration panel

## 📝 Notes

- **Pie Menu Icons**: Fixed the issue where pie menu wasn't showing icons. The problem was that the pie menu was always showing 8 slices, but only 4 had commands assigned. Now it dynamically shows only the slices that have commands, making the icons visible.
- **App Detection**: Enhanced app detection with partial name matching to better identify apps like Figma.
- **Dynamic Slices**: Pie menu now adapts to show only the number of slices needed based on assigned commands.
- **Splash Screen**: Added a professional splash screen that displays for 4 seconds when the app launches, showing the MacPie logo, app name, version, and an animated loading indicator with "Starting" text.
