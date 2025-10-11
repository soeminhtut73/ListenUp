//
//  SettingController.swift
//  ListenUp
//
//  Created by S M H  on 08/10/2025.
//

import UIKit
import MessageUI
import StoreKit


// MARK: - Settings Section Model
enum SettingsSection: Int, CaseIterable {
    case network = 0
    case notifications
    case storage
    case legal
    
    var title: String {
        switch self {
        case .network: return "Network & Connectivity"
        case .notifications: return "Notifications"
        case .storage: return "Storage Management"
        case .legal: return "Legal & Support"
        }
    }
    
}

// MARK: - Main Settings Controller
class SettingsController: UITableViewController {
    
    // MARK: - Properties
    private let cellIdentifier = "SettingsCell"
    private let switchCellIdentifier = "SwitchCell"
    private let settingsManager = AppSettingsManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Settings"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: switchCellIdentifier)
        tableView.backgroundColor = .systemGroupedBackground
        
        // Add close button if presented modally
        if presentingViewController != nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(dismissSettings)
            )
        }
    }
    
    @objc private func dismissSettings() {
        dismiss(animated: true)
    }
    
    // MARK: - TableView DataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let settingsSection = SettingsSection(rawValue: section) else { return 0 }
        
        switch settingsSection {
        case .network:
            return 1 // Cellular Data Usage
        case .notifications:
            return 3 // Download Complete, Low Storage, Update Notification
        case .storage:
            return 2 // Clear Cache, Clear Data
        case .legal:
            return 6 // About, Terms, Privacy, License, Contact, Rate
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return SettingsSection(rawValue: section)?.title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch section {
        case .network:
            return configureNetworkCell(at: indexPath)
        case .notifications:
            return configureNotificationCell(at: indexPath)
        case .storage:
            return configureStorageCell(at: indexPath)
        case .legal:
            return configureLegalCell(at: indexPath)
        }
    }
    
    // MARK: - Cell Configuration
    private func configureNetworkCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: switchCellIdentifier, for: indexPath) as! SwitchTableViewCell
        cell.configure(
            title: "Use Cellular Data",
            subtitle: "Download content using mobile data",
            isOn: settingsManager.isCellularDataEnabled
        ) { [weak self] isOn in
            self?.settingsManager.isCellularDataEnabled = isOn
        }
        return cell
    }
    
    private func configureNotificationCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: switchCellIdentifier, for: indexPath) as! SwitchTableViewCell
        
        switch indexPath.row {
        case 0:
            cell.configure(
                title: "Download Complete",
                subtitle: nil,
                isOn: settingsManager.isDownloadCompleteNotificationEnabled
            ) { [weak self] isOn in
                self?.settingsManager.isDownloadCompleteNotificationEnabled = isOn
            }
        case 1:
            cell.configure(
                title: "Low Storage Warning",
                subtitle: nil,
                isOn: settingsManager.isLowStorageNotificationEnabled
            ) { [weak self] isOn in
                self?.settingsManager.isLowStorageNotificationEnabled = isOn
            }
        case 2:
            cell.configure(
                title: "App Updates",
                subtitle: nil,
                isOn: settingsManager.isUpdateNotificationEnabled
            ) { [weak self] isOn in
                self?.settingsManager.isUpdateNotificationEnabled = isOn
            }
        default:
            break
        }
        
        return cell
    }
    
    private func configureStorageCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.accessoryType = .disclosureIndicator
        
        switch indexPath.row {
        case 0: // Clear Cache
            cell.textLabel?.text = "Clear Cache"
            cell.textLabel?.textColor = .systemBlue
            
            if let lastClearDate = settingsManager.lastCacheClearDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                cell.detailTextLabel?.text = "Last cleared \(formatter.localizedString(for: lastClearDate, relativeTo: Date()))"
                cell.detailTextLabel?.textColor = .secondaryLabel
            }
            
        case 1: // Clear All Data
            cell.textLabel?.text = "Clear All Data"
            cell.textLabel?.textColor = .systemRed
            cell.detailTextLabel?.text = nil
            
        default:
            break
        }
        
        return cell
    }
    
    private func configureLegalCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.textColor = .label
        
        switch indexPath.row {
        case 0: // About
            cell.textLabel?.text = "About"
            cell.detailTextLabel?.text = "Version \(settingsManager.appVersion) (\(settingsManager.appBuild))"
            cell.detailTextLabel?.textColor = .secondaryLabel
            
        case 1:
            cell.textLabel?.text = "Terms of Service"
            
        case 2:
            cell.textLabel?.text = "Privacy Policy"
            
        case 3:
            cell.textLabel?.text = "Licenses"
            
        case 4:
            cell.textLabel?.text = "Contact Support"
            cell.imageView?.image = UIImage(systemName: "envelope")
            cell.imageView?.tintColor = .systemBlue
            
        case 5:
            cell.textLabel?.text = "Rate the App"
            cell.imageView?.image = UIImage(systemName: "star.fill")
            cell.imageView?.tintColor = .systemYellow
            
        default:
            break
        }
        
        return cell
    }
    
    // MARK: - TableView Delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = SettingsSection(rawValue: indexPath.section) else { return }
        
        switch section {
        case .storage:
            handleStorageSelection(at: indexPath)
        case .legal:
            handleLegalSelection(at: indexPath)
        default:
            break
        }
    }
    
    // MARK: - Action Handlers
    private func handleStorageSelection(at indexPath: IndexPath) {
        switch indexPath.row {
        case 0: // Clear Cache
            showClearCacheAlert()
        case 1: // Clear All Data
            showClearDataAlert()
        default:
            break
        }
    }
    
    private func handleLegalSelection(at indexPath: IndexPath) {
        switch indexPath.row {
        case 0: // About
            showAboutScreen()
        case 1: // Terms of Service
            openWebView(url: "https://example.com/terms")
        case 2: // Privacy Policy
            openWebView(url: "https://example.com/privacy")
        case 3: // Licenses
            showLicensesScreen()
        case 4: // Contact Support
            showContactSupport()
        case 5: // Rate the App
            rateApp()
        default:
            break
        }
    }
    
    // MARK: - Alert Methods
    private func showClearCacheAlert() {
        let alert = UIAlertController(
            title: "Clear Cache",
            message: "This will delete temporary files and free up storage space. Your data and settings will be preserved.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear Cache", style: .default) { [weak self] _ in
            self?.showLoadingIndicator()
            self?.settingsManager.clearCache { success, message in
                self?.hideLoadingIndicator()
                if success {
                    self?.showSuccessMessage(message)
                    self?.tableView.reloadData()
                } else {
                    self?.showErrorMessage(message)
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showClearDataAlert() {
        let alert = UIAlertController(
            title: "Clear All Data",
            message: "⚠️ This will delete all app data including downloads, settings, and preferences. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All Data", style: .destructive) { [weak self] _ in
            // Second confirmation
            let confirmAlert = UIAlertController(
                title: "Are you sure?",
                message: "All your data will be permanently deleted.",
                preferredStyle: .alert
            )
            
            confirmAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            confirmAlert.addAction(UIAlertAction(title: "Delete Everything", style: .destructive) { _ in
                self?.showLoadingIndicator()
                self?.settingsManager.clearAllData { success, message in
                    self?.hideLoadingIndicator()
                    if success {
                        self?.showSuccessMessage(message)
                        self?.tableView.reloadData()
                    } else {
                        self?.showErrorMessage(message)
                    }
                }
            })
            
            self?.present(confirmAlert, animated: true)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Navigation Methods
    private func showAboutScreen() {
        let vc = AboutViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showLicensesScreen() {
        let vc = LicensesViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func openWebView(url: String) {
        if let url = URL(string: url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func showContactSupport() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["support@yourapp.com"])
            mail.setSubject("Support Request - \(settingsManager.appVersion)")
            
            let deviceInfo = """
            
            ---
            App Version: \(settingsManager.appVersion) (\(settingsManager.appBuild))
            Device: \(UIDevice.current.model)
            iOS Version: \(UIDevice.current.systemVersion)
            """
            mail.setMessageBody(deviceInfo, isHTML: false)
            
            present(mail, animated: true)
        } else {
            showAlert(
                title: "Email Not Available",
                message: "Please configure your email account in the Settings app to contact support."
            )
        }
    }
    
    private func rateApp() {
        if let scene = view.window?.windowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    // MARK: - Helper Methods
    private func showLoadingIndicator() {
        let loadingAlert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
    }
    
    private func hideLoadingIndicator() {
        if presentedViewController is UIAlertController {
            dismiss(animated: true)
        }
    }
    
    private func showSuccessMessage(_ message: String) {
        showAlert(title: "Success", message: message)
    }
    
    private func showErrorMessage(_ message: String) {
        showAlert(title: "Error", message: message)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - MFMailComposeViewControllerDelegate
extension SettingsController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}

// MARK: - Custom Switch Cell
class SwitchTableViewCell: UITableViewCell {
    private let switchControl = UISwitch()
    private var onToggle: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        selectionStyle = .none
        accessoryView = switchControl
        switchControl.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
    }
    
    func configure(title: String, subtitle: String? = nil, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        textLabel?.text = title
        detailTextLabel?.text = subtitle
        detailTextLabel?.textColor = .secondaryLabel
        switchControl.isOn = isOn
        self.onToggle = onToggle
    }
    
    @objc private func switchToggled() {
        onToggle?(switchControl.isOn)
    }
}

// MARK: - About View Controller
class AboutViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "About"
        view.backgroundColor = .systemBackground
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // App Icon
        let iconView = UIImageView()
        if let appIcon = UIImage(named: "AppIcon") {
            iconView.image = appIcon
        } else {
            iconView.image = UIImage(systemName: "app.fill")
            iconView.tintColor = .systemBlue
        }
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 20
        iconView.layer.masksToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        // App Name
        let nameLabel = UILabel()
        nameLabel.text = Bundle.main.displayName ?? "App"
        nameLabel.font = .systemFont(ofSize: 28, weight: .bold)
        
        // Version
        let versionLabel = UILabel()
        versionLabel.text = "Version \(AppSettingsManager.shared.appVersion)"
        versionLabel.textColor = .secondaryLabel
        versionLabel.font = .systemFont(ofSize: 16)
        
        // Build
        let buildLabel = UILabel()
        buildLabel.text = "Build \(AppSettingsManager.shared.appBuild)"
        buildLabel.textColor = .tertiaryLabel
        buildLabel.font = .systemFont(ofSize: 14)
        
        // Description
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Thank you for using our app!"
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        descriptionLabel.font = .systemFont(ofSize: 16)
        
        // Copyright
        let copyrightLabel = UILabel()
        let year = Calendar.current.component(.year, from: Date())
        copyrightLabel.text = "© \(year) Your Company. All rights reserved."
        copyrightLabel.textColor = .tertiaryLabel
        copyrightLabel.font = .systemFont(ofSize: 14)
        
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(versionLabel)
        stackView.addArrangedSubview(buildLabel)
        stackView.addArrangedSubview(UIView()) // Spacer
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(copyrightLabel)
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 100),
            iconView.heightAnchor.constraint(equalToConstant: 100),
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])
    }
}

// MARK: - Licenses View Controller
class LicensesViewController: UITableViewController {
    
    private let licenses = [
        ("MIT License", "Your App", "© 2024 Your Company"),
        ("Apache License 2.0", "Third Party Library", "© Example Author"),
        // Add more licenses as needed
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Licenses"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return licenses.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let license = licenses[indexPath.row]
        cell.textLabel?.text = license.1
        cell.detailTextLabel?.text = license.0
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Show license detail
    }
}

// MARK: - Bundle Extension
extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
               object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    var appVersion: String? {
        return object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
    
    var appBuild: String? {
        return object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}
