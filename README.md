# BindBC-Common
This library contains various re-usable code-generation routines & types for the BindBC packages. It is compatible with BetterC, `@nogc`, and `nothrow`.

If you plan to use BindBC-Common for your own projects, then please read thoroughly read the documentation that is embedded in the library's code. Undocumented features, and ones marked as "inernal use only" **should not be used**, as their API may change from one patch to another.

| Table of Contents |
|-------------------|
|[License](#license)|
|[Configurations](#configurations)|

## License

BindBC-Common&mdash;as well as every other library in the [BindBC project](https://github.com/BindBC)&mdash;is licensed under the [Boost Software License](https://www.boost.org/LICENSE_1_0.txt).

## Configurations
BindBC-Common is not configured to compile with BetterC compatibility by default. Users of packages dependent on BindBC-Common should not configure BindBC-Common directly. Those packages have their own configuration options that will select the appropriate loader configuration.

Implementers of bindings using BindBC-Common can make use of two configurations:
* `nobc`, which does not enable BetterC, and is the default.
* `yesbc` enables BetterC.

Binding implementers should typically provide four configuration options. Two for static bindings (BetterC and non-BetterC), and two for dynamic bindings using the `nobc` and `yesbc` configurations of BindBC-Common:

|     ┌      |  DRuntime  |   BetterC   |
|-------------|------------|-------------|
| **Dynamic** | `dynamic`  | `dynamicBC` |
| **Static**  | `static`   | `staticBC`  |

Anyone using multiple BindBC packages with dynamic bindings must ensure that they are all configured to either use BetterC compatibility, or not. Configuring one BindBC package to use the BetterC configuration and another to use the non-BetterC configuration will cause conflicting versions of BindBC-Common to be compiled, resulting in compiler or linker errors.