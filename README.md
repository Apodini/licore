# LI.CO.RE

<p align="center">
    <a href="LICENSE">
        <img src="https://img.shields.io/github/license/Apodini/licore" alt="MIT License">
    </a>
    <a href="https://actions-badge.atrox.dev/Apodini/licore/goto?ref=master"><img alt="Build Status" src="https://img.shields.io/endpoint.svg?url=https%3A%2F%2Factions-badge.atrox.dev%2FApodini%2Flicore%2Fbadge%3Fref%3Dmaster&style=flat" /></a>
    </a>
    <a href="https://swift.org">
        <img src="https://img.shields.io/badge/swift-5.2-brightgreen.svg" alt="Swift 5.2">
    </a>
</p>

`LI.CO.RE` (Lint Code Review) is a scalable and extensible Lint Code Review Bot for GitHub and BitBucket. It uses the SwiftLint framework for the code analysis and posts its outputs as inline comments.

## Requirements
`LI.CO.RE` works with Vapor version 4.0 or higher and requires the Swift version to be 5.2 or higher.

## Building
To build `LI.CO.RE`, please go to the cloned repository folder (e.g. `cd licore`):

```
$ docker-compose build
$ docker-compose up -d
```
After the docker containers are up, `LI.CO.RE` will listen on port 8080. The user for login is `Licore` and the initial password will be `licore`.

## Usage
In this section you will find some instructions for setting up `LI.CO.RE`.

### Set a Password

When starting `LI.CO.RE` for the first time, it is recommended to change the initial password.
For changing the password, please go to the dropdown menu `Configs` and select `Update User`.

![](https://github.com/Apodini/licore/raw/develop/images/Change_Password.png)

### Define your Application URL
For being able to setup Webhooks automatically, it is necessary to enter the URL to your `LI.CO.RE` instance.
For setting the Application URL, please go to the dropdown menu `Configs` and select `Set Hook URL`.

![](https://github.com/Apodini/licore/raw/develop/images/Hook_URL.png)

### Setup a Source Control Management System
To give `LI.CO.RE` access to your Source Control Management System, you can configure `LI.CO.RE` providing the following information:

- `SCM Name`: The name for the current configuration e.g. `BitBucket 1` or `GitHub 1`.
- Your Source Control Management System, currently `BitBucket` and `GitHub`.
- `SCM URL`: The URL to your system e.g. `https://your-url.com`.
- `Username`: The username of the account used by `LI.CO.RE` for logging in.
- `Password`: The password of the account used by `LI.CO.RE` for logging in.

For setting up a Source Control Management System, please go to the dropdown menu `Configs` and select `Create a SCM`.
![](https://github.com/Apodini/licore/raw/develop/images/SCM_Setup.png)

### Setup a Project in `LI.CO.RE`
To make `LI.CO.RE` linting your project, you need to enter your project details.

- `Project Name`: The name for the current configuration of your project.
- `Project Key`: The key of your project from your Source Control Management System.
- `Select SCM`: Select the respective SCM you have specified in [this section](#setup-a-source-control-management-system).
- `Rules`: Here you can specify the linting rules, by entering the content of your `.swiftlint.yml`.
- `Slack Token`: Bot token for your project's Slack workspace. Using this token `LI.CO.RE` is able to send reminder messages to your Developers.

For setting up a Project, please go to the dropdown menu `Configs` and select `Project Configuration`.
![](https://github.com/Apodini/licore/raw/develop/images/Project_Setup.png)

### Setup Repositories & Webhooks & Developers
You are almost there, we need to talk about 3 things:

- `Repository`: The repositories are fetched automatically, when you have configured your project properly. However, if you need to fetch your repositories again, you can do this by clicking `Fetch Repositories`.
- `Hook Me`: By clicking `Hook me` you can set the Webhook for the current repository or for all repositories by clicking `Hook All Repositories`.

   :tada: :tada: :tada: From here `LI.CO.RE` will be able to review your code! :tada: :tada: :tada:

- `Fetch Developers` (optional): If you want to see the repository details with its statistics board you need to fetch the Developers by clicking `Fetch Developers`.

For setting up a Project, please go to the dropdown menu `Configs` and select `Project Configuration`.

![](https://github.com/Apodini/licore/raw/develop/images/Project_Overview.png)

## Contributing
Contributions to this projects are welcome. Please make sure to read the [contribution guidelines](https://github.com/Apodini/.github/blob/master/CONTRIBUTING.md) first.

## License
This project is licensed under the MIT License. See [License](https://github.com/Apodini/Template-Repository/blob/master/LICENSE) for more information.
