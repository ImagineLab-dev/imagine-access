import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Imagine Access'**
  String get appTitle;

  /// No description provided for @adminRRPP.
  ///
  /// In en, this message translates to:
  /// **'Admin / RRPP'**
  String get adminRRPP;

  /// No description provided for @doorAccess.
  ///
  /// In en, this message translates to:
  /// **'Door Access'**
  String get doorAccess;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @deviceID.
  ///
  /// In en, this message translates to:
  /// **'Device Alias'**
  String get deviceID;

  /// No description provided for @pinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN Code'**
  String get pinCode;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get login;

  /// No description provided for @startAccess.
  ///
  /// In en, this message translates to:
  /// **'START ACCESS'**
  String get startAccess;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @totalTickets.
  ///
  /// In en, this message translates to:
  /// **'Total Tickets'**
  String get totalTickets;

  /// No description provided for @checkedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked In'**
  String get checkedIn;

  /// No description provided for @scanned.
  ///
  /// In en, this message translates to:
  /// **'Scanned'**
  String get scanned;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get capacity;

  /// No description provided for @createTicket.
  ///
  /// In en, this message translates to:
  /// **'Create Ticket'**
  String get createTicket;

  /// No description provided for @viewTickets.
  ///
  /// In en, this message translates to:
  /// **'View Tickets'**
  String get viewTickets;

  /// No description provided for @scanMode.
  ///
  /// In en, this message translates to:
  /// **'Scan Mode'**
  String get scanMode;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @defaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default Currency'**
  String get defaultCurrency;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @accessControl.
  ///
  /// In en, this message translates to:
  /// **'Access Control'**
  String get accessControl;

  /// No description provided for @userManagement.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userManagement;

  /// No description provided for @userManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage Admins, RRPP, and Staff roles'**
  String get userManagementDesc;

  /// No description provided for @deviceManagement.
  ///
  /// In en, this message translates to:
  /// **'Device Management'**
  String get deviceManagement;

  /// No description provided for @deviceManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage scanning devices and PINs'**
  String get deviceManagementDesc;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutDesc.
  ///
  /// In en, this message translates to:
  /// **'Exit application'**
  String get signOutDesc;

  /// No description provided for @teamMembers.
  ///
  /// In en, this message translates to:
  /// **'Team Members'**
  String get teamMembers;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @rrpp.
  ///
  /// In en, this message translates to:
  /// **'RRPP'**
  String get rrpp;

  /// No description provided for @door.
  ///
  /// In en, this message translates to:
  /// **'Door'**
  String get door;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @noDevicesRegistered.
  ///
  /// In en, this message translates to:
  /// **'No devices registered'**
  String get noDevicesRegistered;

  /// No description provided for @addNewDevice.
  ///
  /// In en, this message translates to:
  /// **'Add New Device'**
  String get addNewDevice;

  /// No description provided for @alias.
  ///
  /// In en, this message translates to:
  /// **'Alias (e.g. Gate 1)'**
  String get alias;

  /// No description provided for @deviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceIdLabel;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinLabel;

  /// No description provided for @savePinWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Save this PIN now. It cannot be viewed again'**
  String get savePinWarning;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @manageEvents.
  ///
  /// In en, this message translates to:
  /// **'Manage Events'**
  String get manageEvents;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @noEventsFound.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get noEventsFound;

  /// No description provided for @createEvent.
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get createEvent;

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEvent;

  /// No description provided for @eventDetails.
  ///
  /// In en, this message translates to:
  /// **'Event Details'**
  String get eventDetails;

  /// No description provided for @eventName.
  ///
  /// In en, this message translates to:
  /// **'Event Name'**
  String get eventName;

  /// No description provided for @slug.
  ///
  /// In en, this message translates to:
  /// **'Slug (URL ID)'**
  String get slug;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @venueName.
  ///
  /// In en, this message translates to:
  /// **'Venue Name'**
  String get venueName;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @ticketTypes.
  ///
  /// In en, this message translates to:
  /// **'Ticket Types'**
  String get ticketTypes;

  /// No description provided for @addTicketType.
  ///
  /// In en, this message translates to:
  /// **'Add Ticket Type'**
  String get addTicketType;

  /// No description provided for @saveEvent.
  ///
  /// In en, this message translates to:
  /// **'SAVE EVENT'**
  String get saveEvent;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @tickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get tickets;

  /// No description provided for @newTicket.
  ///
  /// In en, this message translates to:
  /// **'New Ticket'**
  String get newTicket;

  /// No description provided for @buyerInfo.
  ///
  /// In en, this message translates to:
  /// **'Buyer Info'**
  String get buyerInfo;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @idNumber.
  ///
  /// In en, this message translates to:
  /// **'ID Number'**
  String get idNumber;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @ticketDetails.
  ///
  /// In en, this message translates to:
  /// **'Ticket Details'**
  String get ticketDetails;

  /// No description provided for @event.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get event;

  /// No description provided for @ticketType.
  ///
  /// In en, this message translates to:
  /// **'Ticket Type'**
  String get ticketType;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get back;

  /// No description provided for @confirmPurchase.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PURCHASE'**
  String get confirmPurchase;

  /// No description provided for @searchTickets.
  ///
  /// In en, this message translates to:
  /// **'Search tickets...'**
  String get searchTickets;

  /// No description provided for @filterByEvent.
  ///
  /// In en, this message translates to:
  /// **'Filter by Event'**
  String get filterByEvent;

  /// No description provided for @allEvents.
  ///
  /// In en, this message translates to:
  /// **'All Events'**
  String get allEvents;

  /// No description provided for @valid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get valid;

  /// No description provided for @used.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get used;

  /// No description provided for @voided.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get voided;

  /// No description provided for @scanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get scanner;

  /// No description provided for @scanQRCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQRCode;

  /// No description provided for @accessGranted.
  ///
  /// In en, this message translates to:
  /// **'ACCESS GRANTED'**
  String get accessGranted;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'ACCESS DENIED'**
  String get accessDenied;

  /// No description provided for @alreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'ALREADY USED'**
  String get alreadyUsed;

  /// No description provided for @invalidTicket.
  ///
  /// In en, this message translates to:
  /// **'INVALID TICKET'**
  String get invalidTicket;

  /// No description provided for @tapToScan.
  ///
  /// In en, this message translates to:
  /// **'Tap to Scan'**
  String get tapToScan;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @enableStaffTickets.
  ///
  /// In en, this message translates to:
  /// **'Enable Staff/Crew Tickets'**
  String get enableStaffTickets;

  /// No description provided for @enableGuestTickets.
  ///
  /// In en, this message translates to:
  /// **'Enable Guest List/Invitations'**
  String get enableGuestTickets;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @standardGuests.
  ///
  /// In en, this message translates to:
  /// **'Standard Guests'**
  String get standardGuests;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @enteringPerHour.
  ///
  /// In en, this message translates to:
  /// **'Entering Per Hour'**
  String get enteringPerHour;

  /// No description provided for @rrppPerformance.
  ///
  /// In en, this message translates to:
  /// **'RRPP Performance'**
  String get rrppPerformance;

  /// No description provided for @salesTrend.
  ///
  /// In en, this message translates to:
  /// **'Sales Trend'**
  String get salesTrend;

  /// No description provided for @pleaseSelectEvent.
  ///
  /// In en, this message translates to:
  /// **'Please select an event first!'**
  String get pleaseSelectEvent;

  /// No description provided for @selectEvent.
  ///
  /// In en, this message translates to:
  /// **'Select Event'**
  String get selectEvent;

  /// No description provided for @couldNotLoadActivity.
  ///
  /// In en, this message translates to:
  /// **'Could not load activity'**
  String get couldNotLoadActivity;

  /// No description provided for @noRecentScans.
  ///
  /// In en, this message translates to:
  /// **'No recent scans'**
  String get noRecentScans;

  /// No description provided for @viewAllTickets.
  ///
  /// In en, this message translates to:
  /// **'VIEW ALL TICKETS'**
  String get viewAllTickets;

  /// No description provided for @ticketCreated.
  ///
  /// In en, this message translates to:
  /// **'Ticket Created!'**
  String get ticketCreated;

  /// No description provided for @pdfGeneratedDesc.
  ///
  /// In en, this message translates to:
  /// **'PDF generated and Email sent via SendGrid.'**
  String get pdfGeneratedDesc;

  /// No description provided for @createAnother.
  ///
  /// In en, this message translates to:
  /// **'Create Another'**
  String get createAnother;

  /// No description provided for @selectTicketType.
  ///
  /// In en, this message translates to:
  /// **'Select Ticket Type'**
  String get selectTicketType;

  /// No description provided for @noTicketTypesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No ticket types available for this event.'**
  String get noTicketTypesAvailable;

  /// No description provided for @reviewDetails.
  ///
  /// In en, this message translates to:
  /// **'Review Details'**
  String get reviewDetails;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @createAndSend.
  ///
  /// In en, this message translates to:
  /// **'CREATE & SEND'**
  String get createAndSend;

  /// No description provided for @pleaseSelectTicketType.
  ///
  /// In en, this message translates to:
  /// **'Please select a ticket type'**
  String get pleaseSelectTicketType;

  /// No description provided for @deleteEventQuery.
  ///
  /// In en, this message translates to:
  /// **'Delete Event?'**
  String get deleteEventQuery;

  /// No description provided for @deleteEventConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete event? This cannot be undone if tickets exist.'**
  String get deleteEventConfirm;

  /// No description provided for @deleteErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete: Tickets likely exist. Archive instead.'**
  String get deleteErrorMessage;

  /// No description provided for @whatToDo.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get whatToDo;

  /// No description provided for @selectForScanning.
  ///
  /// In en, this message translates to:
  /// **'SELECT FOR SCANNING'**
  String get selectForScanning;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @types.
  ///
  /// In en, this message translates to:
  /// **'Types'**
  String get types;

  /// No description provided for @guestList.
  ///
  /// In en, this message translates to:
  /// **'GUEST LIST'**
  String get guestList;

  /// No description provided for @noTicketsFound.
  ///
  /// In en, this message translates to:
  /// **'No tickets found'**
  String get noTicketsFound;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search guest or email...'**
  String get searchHint;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get all;

  /// No description provided for @validCaps.
  ///
  /// In en, this message translates to:
  /// **'VALID'**
  String get validCaps;

  /// No description provided for @usedCaps.
  ///
  /// In en, this message translates to:
  /// **'USED'**
  String get usedCaps;

  /// No description provided for @voidCaps.
  ///
  /// In en, this message translates to:
  /// **'VOID'**
  String get voidCaps;

  /// No description provided for @readyToScan.
  ///
  /// In en, this message translates to:
  /// **'Ready to Scan'**
  String get readyToScan;

  /// No description provided for @firstEntry.
  ///
  /// In en, this message translates to:
  /// **'FIRST ENTRY:'**
  String get firstEntry;

  /// No description provided for @tapToDismiss.
  ///
  /// In en, this message translates to:
  /// **'TAP TO DISMISS'**
  String get tapToDismiss;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get newEvent;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @currencyLabel.
  ///
  /// In en, this message translates to:
  /// **'CURRENCY'**
  String get currencyLabel;

  /// No description provided for @addType.
  ///
  /// In en, this message translates to:
  /// **'Add Type'**
  String get addType;

  /// No description provided for @noTicketTypesAdded.
  ///
  /// In en, this message translates to:
  /// **'No ticket types added yet.'**
  String get noTicketTypesAdded;

  /// No description provided for @forceRefresh.
  ///
  /// In en, this message translates to:
  /// **'Force App Refresh'**
  String get forceRefresh;

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing data...'**
  String get refreshing;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend Email'**
  String get resendEmail;

  /// No description provided for @voidTicket.
  ///
  /// In en, this message translates to:
  /// **'Void Ticket'**
  String get voidTicket;

  /// No description provided for @confirmVoid.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to void this ticket?'**
  String get confirmVoid;

  /// No description provided for @ticketVoided.
  ///
  /// In en, this message translates to:
  /// **'Ticket voided successfully'**
  String get ticketVoided;

  /// No description provided for @emailResent.
  ///
  /// In en, this message translates to:
  /// **'Email resent successfully'**
  String get emailResent;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @voiding.
  ///
  /// In en, this message translates to:
  /// **'Voiding...'**
  String get voiding;

  /// No description provided for @emailSent.
  ///
  /// In en, this message translates to:
  /// **'Email Sent'**
  String get emailSent;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'REGISTER'**
  String get register;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signUp;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @doNotHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get doNotHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @manageTeam.
  ///
  /// In en, this message translates to:
  /// **'Manage Team'**
  String get manageTeam;

  /// No description provided for @mySales.
  ///
  /// In en, this message translates to:
  /// **'MY SALES'**
  String get mySales;

  /// No description provided for @validated.
  ///
  /// In en, this message translates to:
  /// **'VALIDATED'**
  String get validated;

  /// No description provided for @guestsIn.
  ///
  /// In en, this message translates to:
  /// **'GUESTS IN'**
  String get guestsIn;

  /// No description provided for @myQuotas.
  ///
  /// In en, this message translates to:
  /// **'MY QUOTAS'**
  String get myQuotas;

  /// No description provided for @commission.
  ///
  /// In en, this message translates to:
  /// **'COMMISSION'**
  String get commission;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get pending;

  /// No description provided for @toEnter.
  ///
  /// In en, this message translates to:
  /// **'TO ENTER'**
  String get toEnter;

  /// No description provided for @guestEntry.
  ///
  /// In en, this message translates to:
  /// **'GUEST ENTRY'**
  String get guestEntry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'REFRESH'**
  String get refresh;

  /// No description provided for @staff.
  ///
  /// In en, this message translates to:
  /// **'STAFF'**
  String get staff;

  /// No description provided for @guests.
  ///
  /// In en, this message translates to:
  /// **'GUESTS'**
  String get guests;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'STANDARD'**
  String get normal;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'VIEW'**
  String get view;

  /// No description provided for @newTicketInvitation.
  ///
  /// In en, this message translates to:
  /// **'NEW TICKET / INVITATION'**
  String get newTicketInvitation;

  /// No description provided for @searchTicketBtn.
  ///
  /// In en, this message translates to:
  /// **'SEARCH TICKET'**
  String get searchTicketBtn;

  /// No description provided for @salesTitle.
  ///
  /// In en, this message translates to:
  /// **'SALES'**
  String get salesTitle;

  /// No description provided for @totalIssued.
  ///
  /// In en, this message translates to:
  /// **'TOTAL ISSUED'**
  String get totalIssued;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get today;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'REMAINING'**
  String get remaining;

  /// No description provided for @invitationsStandard.
  ///
  /// In en, this message translates to:
  /// **'STANDARD INVITATIONS'**
  String get invitationsStandard;

  /// No description provided for @invitationsGuest.
  ///
  /// In en, this message translates to:
  /// **'GUEST INVITATIONS'**
  String get invitationsGuest;

  /// No description provided for @entered.
  ///
  /// In en, this message translates to:
  /// **'ENTERED'**
  String get entered;

  /// No description provided for @toEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'TO ENTER'**
  String get toEnterTitle;

  /// No description provided for @paidShort.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get paidShort;

  /// No description provided for @inviteShort.
  ///
  /// In en, this message translates to:
  /// **'I'**
  String get inviteShort;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Control access, tickets, and validation with elegance and precision'**
  String get welcomeTagline;

  /// No description provided for @welcomeMainFeatures.
  ///
  /// In en, this message translates to:
  /// **'MAIN FEATURES'**
  String get welcomeMainFeatures;

  /// No description provided for @systemOnline.
  ///
  /// In en, this message translates to:
  /// **'System online'**
  String get systemOnline;

  /// No description provided for @lockoutWaitSeconds.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait {seconds}s.'**
  String lockoutWaitSeconds(int seconds);

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials.'**
  String get invalidCredentials;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get companyName;

  /// No description provided for @enterCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Enter your company name'**
  String get enterCompanyName;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get retry;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @reloadLocaleData.
  ///
  /// In en, this message translates to:
  /// **'Reload locale & data'**
  String get reloadLocaleData;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated!'**
  String get updated;

  /// No description provided for @addMember.
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get addMember;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @deleteMemberQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Member?'**
  String get deleteMemberQuestion;

  /// No description provided for @confirmRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name}?'**
  String confirmRemoveMember(String name);

  /// No description provided for @addTeamMember.
  ///
  /// In en, this message translates to:
  /// **'Add Team Member'**
  String get addTeamMember;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @userCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'User created successfully!'**
  String get userCreatedSuccessfully;

  /// No description provided for @createUser.
  ///
  /// In en, this message translates to:
  /// **'Create User'**
  String get createUser;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'THIS DEVICE'**
  String get thisDevice;

  /// No description provided for @deviceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Device enabled'**
  String get deviceEnabled;

  /// No description provided for @deviceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Device disabled'**
  String get deviceDisabled;

  /// No description provided for @deleteDeviceQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Device?'**
  String get deleteDeviceQuestion;

  /// No description provided for @confirmDeleteAlias.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{alias}\"?'**
  String confirmDeleteAlias(String alias);

  /// No description provided for @deviceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Device deleted'**
  String get deviceDeleted;

  /// No description provided for @errorDeletingDevice.
  ///
  /// In en, this message translates to:
  /// **'Error deleting: {error}'**
  String errorDeletingDevice(String error);

  /// No description provided for @pinCopied.
  ///
  /// In en, this message translates to:
  /// **'PIN copied!'**
  String get pinCopied;

  /// No description provided for @deviceCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Device created successfully!'**
  String get deviceCreatedSuccessfully;

  /// No description provided for @failedToCreateDevice.
  ///
  /// In en, this message translates to:
  /// **'Failed to create device: {error}'**
  String failedToCreateDevice(String error);

  /// No description provided for @teamForEvent.
  ///
  /// In en, this message translates to:
  /// **'Team: {eventName}'**
  String teamForEvent(String eventName);

  /// No description provided for @addStaffToEvent.
  ///
  /// In en, this message translates to:
  /// **'Add Staff to Event'**
  String get addStaffToEvent;

  /// No description provided for @noStaffAssignedToEvent.
  ///
  /// In en, this message translates to:
  /// **'No staff assigned to this event.'**
  String get noStaffAssignedToEvent;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get unknownUser;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @standardShort.
  ///
  /// In en, this message translates to:
  /// **'STANDARD'**
  String get standardShort;

  /// No description provided for @invitationShort.
  ///
  /// In en, this message translates to:
  /// **'INVIT'**
  String get invitationShort;

  /// No description provided for @vipShort.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get vipShort;

  /// No description provided for @selectUser.
  ///
  /// In en, this message translates to:
  /// **'Select User'**
  String get selectUser;

  /// No description provided for @roleInEvent.
  ///
  /// In en, this message translates to:
  /// **'Role in Event'**
  String get roleInEvent;

  /// No description provided for @addAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addAction;

  /// No description provided for @editQuotasFor.
  ///
  /// In en, this message translates to:
  /// **'Edit Quotas: {userName}'**
  String editQuotasFor(String userName);

  /// No description provided for @standardTicketQuota.
  ///
  /// In en, this message translates to:
  /// **'Standard Ticket Quota'**
  String get standardTicketQuota;

  /// No description provided for @guestListQuotaVip.
  ///
  /// In en, this message translates to:
  /// **'Guest List Quota (VIP)'**
  String get guestListQuotaVip;

  /// No description provided for @invitationQuotaNormal.
  ///
  /// In en, this message translates to:
  /// **'Invitation Quota (Normal)'**
  String get invitationQuotaNormal;

  /// No description provided for @manualUpper.
  ///
  /// In en, this message translates to:
  /// **'MANUAL'**
  String get manualUpper;

  /// No description provided for @systemUser.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemUser;

  /// No description provided for @activityByLine.
  ///
  /// In en, this message translates to:
  /// **'{buyer} • by {validator}'**
  String activityByLine(String buyer, String validator);

  /// No description provided for @sentByLine.
  ///
  /// In en, this message translates to:
  /// **'Sent by: {sender}'**
  String sentByLine(String sender);

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @sharedTicketMessage.
  ///
  /// In en, this message translates to:
  /// **'Shared ticket\n{link}\n\nID: {id}'**
  String sharedTicketMessage(String link, String id);

  /// No description provided for @errorWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithDetail(String error);

  /// No description provided for @manualSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'MANUAL SEARCH'**
  String get manualSearchTitle;

  /// No description provided for @manualSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the search type and enter data to validate entry.'**
  String get manualSearchDescription;

  /// No description provided for @searchByLabel.
  ///
  /// In en, this message translates to:
  /// **'SEARCH BY'**
  String get searchByLabel;

  /// No description provided for @searchByDocument.
  ///
  /// In en, this message translates to:
  /// **'DOCUMENT (ID)'**
  String get searchByDocument;

  /// No description provided for @searchByPhone.
  ///
  /// In en, this message translates to:
  /// **'PHONE'**
  String get searchByPhone;

  /// No description provided for @documentNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'DOCUMENT NUMBER'**
  String get documentNumberLabel;

  /// No description provided for @phoneNumberLabelUpper.
  ///
  /// In en, this message translates to:
  /// **'PHONE NUMBER'**
  String get phoneNumberLabelUpper;

  /// No description provided for @searchAttendee.
  ///
  /// In en, this message translates to:
  /// **'SEARCH ATTENDEE'**
  String get searchAttendee;

  /// No description provided for @resultsFoundCount.
  ///
  /// In en, this message translates to:
  /// **'{count} RESULTS FOUND:'**
  String resultsFoundCount(int count);

  /// No description provided for @dniCiLabel.
  ///
  /// In en, this message translates to:
  /// **'ID:'**
  String get dniCiLabel;

  /// No description provided for @phoneShortLabel.
  ///
  /// In en, this message translates to:
  /// **'PHONE:'**
  String get phoneShortLabel;

  /// No description provided for @validationReason.
  ///
  /// In en, this message translates to:
  /// **'VALIDATION REASON'**
  String get validationReason;

  /// No description provided for @qrNotReadable.
  ///
  /// In en, this message translates to:
  /// **'QR not readable'**
  String get qrNotReadable;

  /// No description provided for @emailNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Email not received'**
  String get emailNotReceived;

  /// No description provided for @manualValidation.
  ///
  /// In en, this message translates to:
  /// **'Manual Validation'**
  String get manualValidation;

  /// No description provided for @otherManualValidation.
  ///
  /// In en, this message translates to:
  /// **'Other / Manual Validation'**
  String get otherManualValidation;

  /// No description provided for @confirmAndValidate.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM AND VALIDATE'**
  String get confirmAndValidate;

  /// No description provided for @ticketAlreadyUsedInvalid.
  ///
  /// In en, this message translates to:
  /// **'THIS TICKET WAS ALREADY USED OR IS NOT VALID'**
  String get ticketAlreadyUsedInvalid;

  /// No description provided for @manualValidationAudited.
  ///
  /// In en, this message translates to:
  /// **'AUDITED MANUAL VALIDATION'**
  String get manualValidationAudited;

  /// No description provided for @noRecordFound.
  ///
  /// In en, this message translates to:
  /// **'No record found'**
  String get noRecordFound;

  /// No description provided for @eventCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Event created successfully!'**
  String get eventCreatedSuccessfully;

  /// No description provided for @ticketLoadedFromDeepLink.
  ///
  /// In en, this message translates to:
  /// **'Ticket loaded from deep link.'**
  String get ticketLoadedFromDeepLink;

  /// No description provided for @couldNotOpenSharedTicket.
  ///
  /// In en, this message translates to:
  /// **'Could not open the shared ticket.'**
  String get couldNotOpenSharedTicket;

  /// No description provided for @professionalAccessStaff.
  ///
  /// In en, this message translates to:
  /// **'Professional Access (Staff)'**
  String get professionalAccessStaff;

  /// No description provided for @createsStaffAccessTicket.
  ///
  /// In en, this message translates to:
  /// **'Creates \'Staff Access\' ticket (Price: 0)'**
  String get createsStaffAccessTicket;

  /// No description provided for @enableInvitationsNormal.
  ///
  /// In en, this message translates to:
  /// **'Enable Invitations (Normal)'**
  String get enableInvitationsNormal;

  /// No description provided for @createsInvitationTicketForQuotas.
  ///
  /// In en, this message translates to:
  /// **'Creates \'Invitation\' ticket (Price: 0) - For RRPP Quotas'**
  String get createsInvitationTicketForQuotas;

  /// No description provided for @setValidUntilTimeOptional.
  ///
  /// In en, this message translates to:
  /// **'Set Valid Until Time (Optional)'**
  String get setValidUntilTimeOptional;

  /// No description provided for @validUntilTime.
  ///
  /// In en, this message translates to:
  /// **'Valid until: {time}'**
  String validUntilTime(String time);

  /// No description provided for @enableVipGuestList.
  ///
  /// In en, this message translates to:
  /// **'Enable VIP Guest List'**
  String get enableVipGuestList;

  /// No description provided for @createsVipGuestTicketForQuotas.
  ///
  /// In en, this message translates to:
  /// **'Creates \'Special Guest\' ticket (Price: 0) - For VIP Quotas'**
  String get createsVipGuestTicketForQuotas;

  /// No description provided for @eventNotFound.
  ///
  /// In en, this message translates to:
  /// **'Event not found.'**
  String get eventNotFound;

  /// No description provided for @eventSelectedFromDeepLink.
  ///
  /// In en, this message translates to:
  /// **'Event selected from deep link.'**
  String get eventSelectedFromDeepLink;

  /// No description provided for @couldNotOpenSharedEvent.
  ///
  /// In en, this message translates to:
  /// **'Could not open the shared event.'**
  String get couldNotOpenSharedEvent;

  /// No description provided for @selectColor.
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get selectColor;

  /// No description provided for @offlineTicketQueued.
  ///
  /// In en, this message translates to:
  /// **'Offline. Ticket queued for automatic sync.'**
  String get offlineTicketQueued;

  /// No description provided for @ticketCreatedEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Ticket created, but email could not be sent.'**
  String get ticketCreatedEmailFailed;

  /// No description provided for @ticketCreatedEmailError.
  ///
  /// In en, this message translates to:
  /// **'Ticket created, email failed: {error}'**
  String ticketCreatedEmailError(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
