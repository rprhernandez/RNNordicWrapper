
# react-native-nordic-wrapper

## Getting started

`$ npm install react-native-nordic-wrapper --save`

### Mostly automatic installation

`$ react-native link react-native-nordic-wrapper`

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-nordic-wrapper` and add `RNNordicWrapper.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNNordicWrapper.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import com.reactlibrary.RNNordicWrapperPackage;` to the imports at the top of the file
  - Add `new RNNordicWrapperPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-nordic-wrapper'
  	project(':react-native-nordic-wrapper').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-nordic-wrapper/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-nordic-wrapper')
  	```


## Usage
```javascript
import RNNordicWrapper from 'react-native-nordic-wrapper';

// TODO: What to do with the module?
RNNordicWrapper;
```
  