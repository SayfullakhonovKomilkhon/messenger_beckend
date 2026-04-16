import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

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
    Locale('ru'),
  ];

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @error.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get error;

  /// No description provided for @ok.
  ///
  /// In ru, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @copied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get copied;

  /// No description provided for @idCopied.
  ///
  /// In ru, this message translates to:
  /// **'ID скопирован'**
  String get idCopied;

  /// No description provided for @unknown.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестный'**
  String get unknown;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @editProfile.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать профиль'**
  String get editProfile;

  /// No description provided for @privacy.
  ///
  /// In ru, this message translates to:
  /// **'Конфиденциальность'**
  String get privacy;

  /// No description provided for @notifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notifications;

  /// No description provided for @conversations.
  ///
  /// In ru, this message translates to:
  /// **'Беседы'**
  String get conversations;

  /// No description provided for @messageRequests.
  ///
  /// In ru, this message translates to:
  /// **'Запросы сообщений'**
  String get messageRequests;

  /// No description provided for @appearance.
  ///
  /// In ru, this message translates to:
  /// **'Внешний вид'**
  String get appearance;

  /// No description provided for @appLock.
  ///
  /// In ru, this message translates to:
  /// **'Блокировка приложения'**
  String get appLock;

  /// No description provided for @help.
  ///
  /// In ru, this message translates to:
  /// **'Помощь'**
  String get help;

  /// No description provided for @helpInDevelopment.
  ///
  /// In ru, this message translates to:
  /// **'Раздел помощи в разработке'**
  String get helpInDevelopment;

  /// No description provided for @inviteFriend.
  ///
  /// In ru, this message translates to:
  /// **'Пригласить друга'**
  String get inviteFriend;

  /// No description provided for @inviteText.
  ///
  /// In ru, this message translates to:
  /// **'Присоединяйся к Demos! Мой логин: {login}'**
  String inviteText(String login);

  /// No description provided for @regenerateKeys.
  ///
  /// In ru, this message translates to:
  /// **'Пересоздать ключи шифрования'**
  String get regenerateKeys;

  /// No description provided for @keysUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Ключи шифрования обновлены'**
  String get keysUpdated;

  /// No description provided for @logout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logout;

  /// No description provided for @logoutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выход'**
  String get logoutTitle;

  /// No description provided for @logoutConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите выйти?'**
  String get logoutConfirm;

  /// No description provided for @clearAllData.
  ///
  /// In ru, this message translates to:
  /// **'Очистить все данные'**
  String get clearAllData;

  /// No description provided for @clearAllDataConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Это действие необратимо. Все ваши данные будут безвозвратно удалены.'**
  String get clearAllDataConfirm;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// No description provided for @copyId.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать ID'**
  String get copyId;

  /// No description provided for @shareId.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get shareId;

  /// No description provided for @myIdInDemos.
  ///
  /// In ru, this message translates to:
  /// **'Мой ID в Demos: {id}'**
  String myIdInDemos(String id);

  /// No description provided for @appVersion.
  ///
  /// In ru, this message translates to:
  /// **'Demos Chat 1.0.3 — Сквозное шифрование (E2EE)'**
  String get appVersion;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @languageRussian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageEnglish.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @avatarNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя аватара: {name}'**
  String avatarNameLabel(String name);

  /// No description provided for @editProfileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать профиль'**
  String get editProfileTitle;

  /// No description provided for @yourId.
  ///
  /// In ru, this message translates to:
  /// **'Ваш ID'**
  String get yourId;

  /// No description provided for @idDescription.
  ///
  /// In ru, this message translates to:
  /// **'Уникальный идентификатор для поиска и транзакций. Нельзя изменить.'**
  String get idDescription;

  /// No description provided for @nickname.
  ///
  /// In ru, this message translates to:
  /// **'Ник'**
  String get nickname;

  /// No description provided for @nicknameHint.
  ///
  /// In ru, this message translates to:
  /// **'Только русские буквы'**
  String get nicknameHint;

  /// No description provided for @nicknameDescription.
  ///
  /// In ru, this message translates to:
  /// **'Отображаемое имя. Должен быть уникальным.'**
  String get nicknameDescription;

  /// No description provided for @aiAgentName.
  ///
  /// In ru, this message translates to:
  /// **'Имя для ИИ-агента'**
  String get aiAgentName;

  /// No description provided for @aiNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Имя для ИИ и Телепатии'**
  String get aiNameHint;

  /// No description provided for @aiNameDescription.
  ///
  /// In ru, this message translates to:
  /// **'Используется в функциях ИИ-агента и Телепатии.'**
  String get aiNameDescription;

  /// No description provided for @aboutYou.
  ///
  /// In ru, this message translates to:
  /// **'О себе'**
  String get aboutYou;

  /// No description provided for @aboutHint.
  ///
  /// In ru, this message translates to:
  /// **'Расскажите немного о себе'**
  String get aboutHint;

  /// No description provided for @saveChanges.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить изменения'**
  String get saveChanges;

  /// No description provided for @profileUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Профиль обновлён'**
  String get profileUpdated;

  /// No description provided for @errorSaving.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при сохранении'**
  String get errorSaving;

  /// No description provided for @nickCannotBeEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Ник не может быть пустым'**
  String get nickCannotBeEmpty;

  /// No description provided for @pickFromGallery.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать из галереи'**
  String get pickFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Сделать фото'**
  String get takePhoto;

  /// No description provided for @deletePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Удалить фото'**
  String get deletePhoto;

  /// No description provided for @photoUploadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить фото'**
  String get photoUploadFailed;

  /// No description provided for @photoUrlFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить URL загруженного фото'**
  String get photoUrlFailed;

  /// No description provided for @tabMessages.
  ///
  /// In ru, this message translates to:
  /// **'Сообщения'**
  String get tabMessages;

  /// No description provided for @tabCalls.
  ///
  /// In ru, this message translates to:
  /// **'Звонки'**
  String get tabCalls;

  /// No description provided for @tabTelepathy.
  ///
  /// In ru, this message translates to:
  /// **'Телепатия'**
  String get tabTelepathy;

  /// No description provided for @tabSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get tabSettings;

  /// No description provided for @searchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск...'**
  String get searchHint;

  /// No description provided for @newGroup.
  ///
  /// In ru, this message translates to:
  /// **'Новая группа'**
  String get newGroup;

  /// No description provided for @darkThemeMenu.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная тема'**
  String get darkThemeMenu;

  /// No description provided for @lightThemeMenu.
  ///
  /// In ru, this message translates to:
  /// **'Светлая тема'**
  String get lightThemeMenu;

  /// No description provided for @wallet.
  ///
  /// In ru, this message translates to:
  /// **'Кошелёк'**
  String get wallet;

  /// No description provided for @markAsRead.
  ///
  /// In ru, this message translates to:
  /// **'Пометить прочитанным'**
  String get markAsRead;

  /// No description provided for @clearHistory.
  ///
  /// In ru, this message translates to:
  /// **'Очистить историю'**
  String get clearHistory;

  /// No description provided for @failedToLoadChats.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить чаты'**
  String get failedToLoadChats;

  /// No description provided for @noChatsYet.
  ///
  /// In ru, this message translates to:
  /// **'Чатов пока нет'**
  String get noChatsYet;

  /// No description provided for @findContactViaSearch.
  ///
  /// In ru, this message translates to:
  /// **'Найдите собеседника через поиск'**
  String get findContactViaSearch;

  /// No description provided for @chatsSection.
  ///
  /// In ru, this message translates to:
  /// **'Чаты'**
  String get chatsSection;

  /// No description provided for @usersSection.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи'**
  String get usersSection;

  /// No description provided for @foundById.
  ///
  /// In ru, this message translates to:
  /// **'Найден по ID'**
  String get foundById;

  /// No description provided for @foundByAvatarName.
  ///
  /// In ru, this message translates to:
  /// **'Найден по имени аватара'**
  String get foundByAvatarName;

  /// No description provided for @foundByNickname.
  ///
  /// In ru, this message translates to:
  /// **'Найден по нику'**
  String get foundByNickname;

  /// No description provided for @nothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get nothingFound;

  /// No description provided for @failedToLoadCalls.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить историю звонков'**
  String get failedToLoadCalls;

  /// No description provided for @noCallsYet.
  ///
  /// In ru, this message translates to:
  /// **'Звонков пока нет'**
  String get noCallsYet;

  /// No description provided for @callHistoryHere.
  ///
  /// In ru, this message translates to:
  /// **'Здесь будет история ваших звонков'**
  String get callHistoryHere;

  /// No description provided for @videoCall.
  ///
  /// In ru, this message translates to:
  /// **'Видеозвонок'**
  String get videoCall;

  /// No description provided for @audioCall.
  ///
  /// In ru, this message translates to:
  /// **'Аудиозвонок'**
  String get audioCall;

  /// No description provided for @group.
  ///
  /// In ru, this message translates to:
  /// **'Группа'**
  String get group;

  /// No description provided for @noMessagesPreview.
  ///
  /// In ru, this message translates to:
  /// **'Сообщений пока нет'**
  String get noMessagesPreview;

  /// No description provided for @voiceMessage.
  ///
  /// In ru, this message translates to:
  /// **'Голосовое сообщение'**
  String get voiceMessage;

  /// No description provided for @photo.
  ///
  /// In ru, this message translates to:
  /// **'Фото'**
  String get photo;

  /// No description provided for @video.
  ///
  /// In ru, this message translates to:
  /// **'Видео'**
  String get video;

  /// No description provided for @attachment.
  ///
  /// In ru, this message translates to:
  /// **'Вложение'**
  String get attachment;

  /// No description provided for @encryptedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Зашифрованное сообщение'**
  String get encryptedMessage;

  /// No description provided for @telepathy.
  ///
  /// In ru, this message translates to:
  /// **'Телепатия'**
  String get telepathy;

  /// No description provided for @members.
  ///
  /// In ru, this message translates to:
  /// **'уч.'**
  String get members;

  /// No description provided for @pinTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Закрепить'**
  String get pinTooltip;

  /// No description provided for @muteTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Без звука'**
  String get muteTooltip;

  /// No description provided for @deleteTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get deleteTooltip;

  /// No description provided for @messageHint.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение...'**
  String get messageHint;

  /// No description provided for @monthJanuary.
  ///
  /// In ru, this message translates to:
  /// **'января'**
  String get monthJanuary;

  /// No description provided for @monthFebruary.
  ///
  /// In ru, this message translates to:
  /// **'февраля'**
  String get monthFebruary;

  /// No description provided for @monthMarch.
  ///
  /// In ru, this message translates to:
  /// **'марта'**
  String get monthMarch;

  /// No description provided for @monthApril.
  ///
  /// In ru, this message translates to:
  /// **'апреля'**
  String get monthApril;

  /// No description provided for @monthMay.
  ///
  /// In ru, this message translates to:
  /// **'мая'**
  String get monthMay;

  /// No description provided for @monthJune.
  ///
  /// In ru, this message translates to:
  /// **'июня'**
  String get monthJune;

  /// No description provided for @monthJuly.
  ///
  /// In ru, this message translates to:
  /// **'июля'**
  String get monthJuly;

  /// No description provided for @monthAugust.
  ///
  /// In ru, this message translates to:
  /// **'августа'**
  String get monthAugust;

  /// No description provided for @monthSeptember.
  ///
  /// In ru, this message translates to:
  /// **'сентября'**
  String get monthSeptember;

  /// No description provided for @monthOctober.
  ///
  /// In ru, this message translates to:
  /// **'октября'**
  String get monthOctober;

  /// No description provided for @monthNovember.
  ///
  /// In ru, this message translates to:
  /// **'ноября'**
  String get monthNovember;

  /// No description provided for @monthDecember.
  ///
  /// In ru, this message translates to:
  /// **'декабря'**
  String get monthDecember;

  /// No description provided for @today.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get yesterday;

  /// No description provided for @reply.
  ///
  /// In ru, this message translates to:
  /// **'Ответить'**
  String get reply;

  /// No description provided for @copyText.
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get copyText;

  /// No description provided for @forward.
  ///
  /// In ru, this message translates to:
  /// **'Переслать'**
  String get forward;

  /// No description provided for @pin.
  ///
  /// In ru, this message translates to:
  /// **'Закрепить'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In ru, this message translates to:
  /// **'Открепить'**
  String get unpin;

  /// No description provided for @edit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get edit;

  /// No description provided for @deleteMsg.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get deleteMsg;

  /// No description provided for @editMessage.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать сообщение'**
  String get editMessage;

  /// No description provided for @forwardMessage.
  ///
  /// In ru, this message translates to:
  /// **'Переслать сообщение'**
  String get forwardMessage;

  /// No description provided for @selectedCount.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано: {count}'**
  String selectedCount(int count);

  /// No description provided for @messageForwarded.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение переслано'**
  String get messageForwarded;

  /// No description provided for @groupE2eeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Групповое сквозное шифрование'**
  String get groupE2eeTitle;

  /// No description provided for @groupE2eeDescription.
  ///
  /// In ru, this message translates to:
  /// **'В этой группе используется протокол Sender Keys.\nКаждый участник генерирует свой ключ,\nи все сообщения шифруются так, что только\nучастники группы могут их прочитать.'**
  String get groupE2eeDescription;

  /// No description provided for @membersWithE2ee.
  ///
  /// In ru, this message translates to:
  /// **'{count} участник с E2EE'**
  String membersWithE2ee(int count);

  /// No description provided for @clearHistoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очистить историю'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите очистить историю у всех?'**
  String get clearHistoryConfirm;

  /// No description provided for @clear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clear;

  /// No description provided for @deleteChatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить чат'**
  String get deleteChatTitle;

  /// No description provided for @deleteChatConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить этот чат?'**
  String get deleteChatConfirm;

  /// No description provided for @typingStatus.
  ///
  /// In ru, this message translates to:
  /// **'{name} печатает...'**
  String typingStatus(String name);

  /// No description provided for @typing.
  ///
  /// In ru, this message translates to:
  /// **'печатает...'**
  String get typing;

  /// No description provided for @online.
  ///
  /// In ru, this message translates to:
  /// **'в сети'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In ru, this message translates to:
  /// **'не в сети'**
  String get offline;

  /// No description provided for @searchInChat.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по чату...'**
  String get searchInChat;

  /// No description provided for @errorLoadingMessages.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки сообщений'**
  String get errorLoadingMessages;

  /// No description provided for @noMessagesYet.
  ///
  /// In ru, this message translates to:
  /// **'Сообщений пока нет'**
  String get noMessagesYet;

  /// No description provided for @enableNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Включить уведомления'**
  String get enableNotifications;

  /// No description provided for @disableNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Выключить уведомления'**
  String get disableNotifications;

  /// No description provided for @encryption.
  ///
  /// In ru, this message translates to:
  /// **'Шифрование'**
  String get encryption;

  /// No description provided for @clearHistoryAll.
  ///
  /// In ru, this message translates to:
  /// **'Очистить историю у всех'**
  String get clearHistoryAll;

  /// No description provided for @deleteChat.
  ///
  /// In ru, this message translates to:
  /// **'Удалить чат'**
  String get deleteChat;

  /// No description provided for @groupInfo.
  ///
  /// In ru, this message translates to:
  /// **'Инфо о группе'**
  String get groupInfo;

  /// No description provided for @pinnedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Закреплённое сообщение'**
  String get pinnedMessage;

  /// No description provided for @you.
  ///
  /// In ru, this message translates to:
  /// **'Вы'**
  String get you;

  /// No description provided for @fileUploadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки файла'**
  String get fileUploadError;

  /// No description provided for @micPermissionError.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к микрофону'**
  String get micPermissionError;

  /// No description provided for @voiceUploadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки голосового'**
  String get voiceUploadError;

  /// No description provided for @voiceSendError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка отправки голосового'**
  String get voiceSendError;

  /// No description provided for @trustBannerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доверять этому пользователю?'**
  String get trustBannerTitle;

  /// No description provided for @trustBannerDescription.
  ///
  /// In ru, this message translates to:
  /// **'Если оба собеседника подтвердят доверие, откроются полные профили (имя, аватар, фото).'**
  String get trustBannerDescription;

  /// No description provided for @trustNo.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get trustNo;

  /// No description provided for @trustYes.
  ///
  /// In ru, this message translates to:
  /// **'Доверяю'**
  String get trustYes;

  /// No description provided for @membersCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} участник'**
  String membersCount(int count);

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileTitle;

  /// No description provided for @userFallback.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь'**
  String get userFallback;

  /// No description provided for @userBlocked.
  ///
  /// In ru, this message translates to:
  /// **'{name} заблокирован'**
  String userBlocked(String name);

  /// No description provided for @userUnblocked.
  ///
  /// In ru, this message translates to:
  /// **'{name} разблокирован'**
  String userUnblocked(String name);

  /// No description provided for @blockError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при блокировке'**
  String get blockError;

  /// No description provided for @blockConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать {name}?'**
  String blockConfirmTitle(String name);

  /// No description provided for @blockConfirmMessage.
  ///
  /// In ru, this message translates to:
  /// **'Заблокированный пользователь не сможет отправлять вам сообщения и видеть ваш профиль.'**
  String get blockConfirmMessage;

  /// No description provided for @block.
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать'**
  String get block;

  /// No description provided for @userNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь не найден'**
  String get userNotFound;

  /// No description provided for @info.
  ///
  /// In ru, this message translates to:
  /// **'Информация'**
  String get info;

  /// No description provided for @trustNotConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Доверие не подтверждено'**
  String get trustNotConfirmed;

  /// No description provided for @writeMessage.
  ///
  /// In ru, this message translates to:
  /// **'Написать'**
  String get writeMessage;

  /// No description provided for @callAction.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get callAction;

  /// No description provided for @videoCallAction.
  ///
  /// In ru, this message translates to:
  /// **'Видео'**
  String get videoCallAction;

  /// No description provided for @muteSound.
  ///
  /// In ru, this message translates to:
  /// **'Без звука'**
  String get muteSound;

  /// No description provided for @unmuteSound.
  ///
  /// In ru, this message translates to:
  /// **'Вкл звук'**
  String get unmuteSound;

  /// No description provided for @mediaFiles.
  ///
  /// In ru, this message translates to:
  /// **'Медиафайлы'**
  String get mediaFiles;

  /// No description provided for @viewAll.
  ///
  /// In ru, this message translates to:
  /// **'Все →'**
  String get viewAll;

  /// No description provided for @noMediaFiles.
  ///
  /// In ru, this message translates to:
  /// **'Нет медиафайлов'**
  String get noMediaFiles;

  /// No description provided for @allMedia.
  ///
  /// In ru, this message translates to:
  /// **'Все медиа'**
  String get allMedia;

  /// No description provided for @blockUser.
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать'**
  String get blockUser;

  /// No description provided for @unblockUser.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировать'**
  String get unblockUser;

  /// No description provided for @settingSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройку'**
  String get settingSaveError;

  /// No description provided for @voiceVideoBeta.
  ///
  /// In ru, this message translates to:
  /// **'Голос и видео (Бета)'**
  String get voiceVideoBeta;

  /// No description provided for @voiceVideoCalls.
  ///
  /// In ru, this message translates to:
  /// **'Голосовые и видеозвонки'**
  String get voiceVideoCalls;

  /// No description provided for @allowCalls.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить входящие и исходящие звонки'**
  String get allowCalls;

  /// No description provided for @screenSecurity.
  ///
  /// In ru, this message translates to:
  /// **'Безопасность экрана'**
  String get screenSecurity;

  /// No description provided for @lockApp.
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать приложение'**
  String get lockApp;

  /// No description provided for @lockAppDescription.
  ///
  /// In ru, this message translates to:
  /// **'Использовать Touch ID, Face ID или пароль устройства для входа в Demos'**
  String get lockAppDescription;

  /// No description provided for @readReceipts.
  ///
  /// In ru, this message translates to:
  /// **'Отчеты о прочтении'**
  String get readReceipts;

  /// No description provided for @readReceiptsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Отправлять отчеты о прочтении в личных чатах'**
  String get readReceiptsDescription;

  /// No description provided for @typingIndicators.
  ///
  /// In ru, this message translates to:
  /// **'Индикаторы набора текста'**
  String get typingIndicators;

  /// No description provided for @typingIndicatorsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Видеть и показывать, когда кто-то печатает'**
  String get typingIndicatorsDescription;

  /// No description provided for @linkPreviews.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр ссылок'**
  String get linkPreviews;

  /// No description provided for @linkPreviewsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Создавать превью для поддерживаемых ссылок'**
  String get linkPreviewsDescription;

  /// No description provided for @strategy.
  ///
  /// In ru, this message translates to:
  /// **'Стратегия'**
  String get strategy;

  /// No description provided for @fastMode.
  ///
  /// In ru, this message translates to:
  /// **'Быстрый режим'**
  String get fastMode;

  /// No description provided for @fastModeDescription.
  ///
  /// In ru, this message translates to:
  /// **'Мгновенные уведомления через серверы Google'**
  String get fastModeDescription;

  /// No description provided for @systemSettings.
  ///
  /// In ru, this message translates to:
  /// **'Системные настройки'**
  String get systemSettings;

  /// No description provided for @systemSettingsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Настройки уведомлений устройства'**
  String get systemSettingsDescription;

  /// No description provided for @styleSection.
  ///
  /// In ru, this message translates to:
  /// **'Стиль'**
  String get styleSection;

  /// No description provided for @sound.
  ///
  /// In ru, this message translates to:
  /// **'Звук'**
  String get sound;

  /// No description provided for @soundDefault.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию'**
  String get soundDefault;

  /// No description provided for @soundNone.
  ///
  /// In ru, this message translates to:
  /// **'Без звука'**
  String get soundNone;

  /// No description provided for @soundSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системный'**
  String get soundSystem;

  /// No description provided for @vibration.
  ///
  /// In ru, this message translates to:
  /// **'Вибрация'**
  String get vibration;

  /// No description provided for @vibDefault.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию'**
  String get vibDefault;

  /// No description provided for @vibShort.
  ///
  /// In ru, this message translates to:
  /// **'Короткая'**
  String get vibShort;

  /// No description provided for @vibLong.
  ///
  /// In ru, this message translates to:
  /// **'Длинная'**
  String get vibLong;

  /// No description provided for @vibOff.
  ///
  /// In ru, this message translates to:
  /// **'Отключена'**
  String get vibOff;

  /// No description provided for @popup.
  ///
  /// In ru, this message translates to:
  /// **'Всплывающее окно'**
  String get popup;

  /// No description provided for @popupAlways.
  ///
  /// In ru, this message translates to:
  /// **'Всегда'**
  String get popupAlways;

  /// No description provided for @popupScreenOn.
  ///
  /// In ru, this message translates to:
  /// **'Только при включённом экране'**
  String get popupScreenOn;

  /// No description provided for @popupNever.
  ///
  /// In ru, this message translates to:
  /// **'Никогда'**
  String get popupNever;

  /// No description provided for @inAppSound.
  ///
  /// In ru, this message translates to:
  /// **'Звук в приложении'**
  String get inAppSound;

  /// No description provided for @inAppSoundDescription.
  ///
  /// In ru, this message translates to:
  /// **'Воспроизводить звук, когда приложение открыто'**
  String get inAppSoundDescription;

  /// No description provided for @contentSection.
  ///
  /// In ru, this message translates to:
  /// **'Содержимое'**
  String get contentSection;

  /// No description provided for @notificationContent.
  ///
  /// In ru, this message translates to:
  /// **'Содержимое уведомлений'**
  String get notificationContent;

  /// No description provided for @contentNameAndText.
  ///
  /// In ru, this message translates to:
  /// **'Имя и текст'**
  String get contentNameAndText;

  /// No description provided for @contentNameOnly.
  ///
  /// In ru, this message translates to:
  /// **'Только имя'**
  String get contentNameOnly;

  /// No description provided for @contentHidden.
  ///
  /// In ru, this message translates to:
  /// **'Без содержимого'**
  String get contentHidden;

  /// No description provided for @mediaPreview.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр медиа'**
  String get mediaPreview;

  /// No description provided for @mediaPreviewDescription.
  ///
  /// In ru, this message translates to:
  /// **'Показывать фото и видео в уведомлениях'**
  String get mediaPreviewDescription;

  /// No description provided for @exceptions.
  ///
  /// In ru, this message translates to:
  /// **'Исключения'**
  String get exceptions;

  /// No description provided for @doNotDisturb.
  ///
  /// In ru, this message translates to:
  /// **'Режим «Не беспокоить»'**
  String get doNotDisturb;

  /// No description provided for @doNotDisturbDescription.
  ///
  /// In ru, this message translates to:
  /// **'Не показывать уведомления в определённое время'**
  String get doNotDisturbDescription;

  /// No description provided for @notificationSound.
  ///
  /// In ru, this message translates to:
  /// **'Звук уведомлений'**
  String get notificationSound;

  /// No description provided for @popupNotification.
  ///
  /// In ru, this message translates to:
  /// **'Всплывающее уведомление'**
  String get popupNotification;

  /// No description provided for @create.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get create;

  /// No description provided for @groupName.
  ///
  /// In ru, this message translates to:
  /// **'Название группы'**
  String get groupName;

  /// No description provided for @groupDescriptionOptional.
  ///
  /// In ru, this message translates to:
  /// **'Описание (необязательно)'**
  String get groupDescriptionOptional;

  /// No description provided for @searchByNameOrId.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по имени или ID...'**
  String get searchByNameOrId;

  /// No description provided for @enterGroupName.
  ///
  /// In ru, this message translates to:
  /// **'Введите название группы'**
  String get enterGroupName;

  /// No description provided for @foundByName.
  ///
  /// In ru, this message translates to:
  /// **'Найден по имени'**
  String get foundByName;

  /// No description provided for @idUser.
  ///
  /// In ru, this message translates to:
  /// **'ID пользователь'**
  String get idUser;

  /// No description provided for @messageCleanup.
  ///
  /// In ru, this message translates to:
  /// **'Очистка сообщений'**
  String get messageCleanup;

  /// No description provided for @communityCleanup.
  ///
  /// In ru, this message translates to:
  /// **'Очистка сообществ'**
  String get communityCleanup;

  /// No description provided for @communityCleanupDescription.
  ///
  /// In ru, this message translates to:
  /// **'Удалять сообщения из сообществ старше 6 месяцев или если их более 2000'**
  String get communityCleanupDescription;

  /// No description provided for @enterKey.
  ///
  /// In ru, this message translates to:
  /// **'Клавиша Enter'**
  String get enterKey;

  /// No description provided for @enterSends.
  ///
  /// In ru, this message translates to:
  /// **'Отправка клавишей Enter'**
  String get enterSends;

  /// No description provided for @enterSendsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Нажатие клавиши Enter отправит ваше сообщение'**
  String get enterSendsDescription;

  /// No description provided for @voiceMessages.
  ///
  /// In ru, this message translates to:
  /// **'Голосовые сообщения'**
  String get voiceMessages;

  /// No description provided for @autoPlay.
  ///
  /// In ru, this message translates to:
  /// **'Автовоспроизведение'**
  String get autoPlay;

  /// No description provided for @autoPlayDescription.
  ///
  /// In ru, this message translates to:
  /// **'Автоматически воспроизводить сообщения по очереди'**
  String get autoPlayDescription;

  /// No description provided for @blockedContacts.
  ///
  /// In ru, this message translates to:
  /// **'Заблокированные контакты'**
  String get blockedContacts;

  /// No description provided for @theme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get theme;

  /// No description provided for @accentColor.
  ///
  /// In ru, this message translates to:
  /// **'Акцентный цвет'**
  String get accentColor;

  /// No description provided for @chatWallpaper.
  ///
  /// In ru, this message translates to:
  /// **'Фон чата'**
  String get chatWallpaper;

  /// No description provided for @systemTheme.
  ///
  /// In ru, this message translates to:
  /// **'Системная тема'**
  String get systemTheme;

  /// No description provided for @followSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get followSystem;

  /// No description provided for @unblockConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировать {name}?'**
  String unblockConfirm(String name);

  /// No description provided for @contactUnblocked.
  ///
  /// In ru, this message translates to:
  /// **'Контакт разблокирован'**
  String get contactUnblocked;

  /// No description provided for @noBlockedContacts.
  ///
  /// In ru, this message translates to:
  /// **'Нет заблокированных контактов'**
  String get noBlockedContacts;

  /// No description provided for @blockedContactsHint.
  ///
  /// In ru, this message translates to:
  /// **'Заблокированные вами контакты\nпоявятся здесь'**
  String get blockedContactsHint;

  /// No description provided for @requestAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Запрос принят'**
  String get requestAccepted;

  /// No description provided for @acceptError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при принятии'**
  String get acceptError;

  /// No description provided for @requestDeclinedBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Запрос отклонён, пользователь заблокирован'**
  String get requestDeclinedBlocked;

  /// No description provided for @requestDeclined.
  ///
  /// In ru, this message translates to:
  /// **'Запрос отклонён'**
  String get requestDeclined;

  /// No description provided for @declineError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при отклонении'**
  String get declineError;

  /// No description provided for @decline.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить'**
  String get decline;

  /// No description provided for @declineAndBlock.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить и заблокировать'**
  String get declineAndBlock;

  /// No description provided for @clearAllRequests.
  ///
  /// In ru, this message translates to:
  /// **'Очистить все'**
  String get clearAllRequests;

  /// No description provided for @clearAllRequestsConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите отклонить все запросы сообщений?'**
  String get clearAllRequestsConfirm;

  /// No description provided for @declineAll.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить все'**
  String get declineAll;

  /// No description provided for @allRequestsDeclined.
  ///
  /// In ru, this message translates to:
  /// **'Все запросы отклонены'**
  String get allRequestsDeclined;

  /// No description provided for @clearRequestsError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при очистке'**
  String get clearRequestsError;

  /// No description provided for @noRequests.
  ///
  /// In ru, this message translates to:
  /// **'Запросов нет'**
  String get noRequests;

  /// No description provided for @noRequestsHint.
  ///
  /// In ru, this message translates to:
  /// **'Запросы от новых контактов появятся здесь'**
  String get noRequestsHint;

  /// No description provided for @noMessages.
  ///
  /// In ru, this message translates to:
  /// **'Нет сообщений'**
  String get noMessages;

  /// No description provided for @accept.
  ///
  /// In ru, this message translates to:
  /// **'Принять'**
  String get accept;

  /// No description provided for @e2eeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сквозное шифрование'**
  String get e2eeTitle;

  /// No description provided for @e2eeDescription.
  ///
  /// In ru, this message translates to:
  /// **'Сообщения в этом чате защищены сквозным шифрованием. Только вы и {name} можете читать их.'**
  String e2eeDescription(String name);

  /// No description provided for @securityCode.
  ///
  /// In ru, this message translates to:
  /// **'Код безопасности'**
  String get securityCode;

  /// No description provided for @securityCodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Сравните этот код с кодом у {name}, чтобы убедиться в безопасности чата.'**
  String securityCodeHint(String name);

  /// No description provided for @copyCode.
  ///
  /// In ru, this message translates to:
  /// **'Копировать код'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In ru, this message translates to:
  /// **'Код скопирован'**
  String get codeCopied;

  /// No description provided for @securityCodeUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Код безопасности станет доступен после обмена сообщениями.'**
  String get securityCodeUnavailable;

  /// No description provided for @wallpaperLove.
  ///
  /// In ru, this message translates to:
  /// **'Любовь'**
  String get wallpaperLove;

  /// No description provided for @wallpaperStarwars.
  ///
  /// In ru, this message translates to:
  /// **'Star Wars'**
  String get wallpaperStarwars;

  /// No description provided for @wallpaperDoodles.
  ///
  /// In ru, this message translates to:
  /// **'Дудлы'**
  String get wallpaperDoodles;

  /// No description provided for @wallpaperMath.
  ///
  /// In ru, this message translates to:
  /// **'Математика'**
  String get wallpaperMath;

  /// No description provided for @wallpaperCosmos.
  ///
  /// In ru, this message translates to:
  /// **'Космос'**
  String get wallpaperCosmos;

  /// No description provided for @wallpaperNone.
  ///
  /// In ru, this message translates to:
  /// **'Без фона'**
  String get wallpaperNone;

  /// No description provided for @myBots.
  ///
  /// In ru, this message translates to:
  /// **'Мои боты'**
  String get myBots;

  /// No description provided for @createBot.
  ///
  /// In ru, this message translates to:
  /// **'Создать бота'**
  String get createBot;

  /// No description provided for @botName.
  ///
  /// In ru, this message translates to:
  /// **'Имя бота'**
  String get botName;

  /// No description provided for @botUsername.
  ///
  /// In ru, this message translates to:
  /// **'Имя пользователя бота'**
  String get botUsername;

  /// No description provided for @botDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get botDescription;

  /// No description provided for @botDescriptionHint.
  ///
  /// In ru, this message translates to:
  /// **'Что делает этот бот?'**
  String get botDescriptionHint;

  /// No description provided for @botAvatar.
  ///
  /// In ru, this message translates to:
  /// **'Аватар'**
  String get botAvatar;

  /// No description provided for @botWebhookUrl.
  ///
  /// In ru, this message translates to:
  /// **'URL вебхука'**
  String get botWebhookUrl;

  /// No description provided for @botWebhookHint.
  ///
  /// In ru, this message translates to:
  /// **'https://example.com/webhook'**
  String get botWebhookHint;

  /// No description provided for @botToken.
  ///
  /// In ru, this message translates to:
  /// **'Токен бота'**
  String get botToken;

  /// No description provided for @botTokenCopied.
  ///
  /// In ru, this message translates to:
  /// **'Токен скопирован'**
  String get botTokenCopied;

  /// No description provided for @botRegenerateToken.
  ///
  /// In ru, this message translates to:
  /// **'Пересоздать токен'**
  String get botRegenerateToken;

  /// No description provided for @botRegenerateTokenConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировать новый токен? Старый перестанет работать.'**
  String get botRegenerateTokenConfirm;

  /// No description provided for @botSetWebhook.
  ///
  /// In ru, this message translates to:
  /// **'Установить вебхук'**
  String get botSetWebhook;

  /// No description provided for @botDeleteWebhook.
  ///
  /// In ru, this message translates to:
  /// **'Удалить вебхук'**
  String get botDeleteWebhook;

  /// No description provided for @botDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить бота'**
  String get botDelete;

  /// No description provided for @botDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить бота? Это действие необратимо.'**
  String get botDeleteConfirm;

  /// No description provided for @botCreated.
  ///
  /// In ru, this message translates to:
  /// **'Бот создан'**
  String get botCreated;

  /// No description provided for @botUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Бот обновлён'**
  String get botUpdated;

  /// No description provided for @botDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Бот удалён'**
  String get botDeleted;

  /// No description provided for @botActive.
  ///
  /// In ru, this message translates to:
  /// **'Активен'**
  String get botActive;

  /// No description provided for @botInactive.
  ///
  /// In ru, this message translates to:
  /// **'Неактивен'**
  String get botInactive;

  /// No description provided for @botToggleActive.
  ///
  /// In ru, this message translates to:
  /// **'Вкл/Выкл бота'**
  String get botToggleActive;

  /// No description provided for @noBots.
  ///
  /// In ru, this message translates to:
  /// **'Ботов пока нет'**
  String get noBots;

  /// No description provided for @noBotsHint.
  ///
  /// In ru, this message translates to:
  /// **'Создайте своего первого бота'**
  String get noBotsHint;

  /// No description provided for @botNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Имя бота обязательно'**
  String get botNameRequired;

  /// No description provided for @botUsernameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Имя пользователя бота обязательно'**
  String get botUsernameRequired;

  /// No description provided for @botBadge.
  ///
  /// In ru, this message translates to:
  /// **'БОТ'**
  String get botBadge;

  /// No description provided for @botEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать бота'**
  String get botEditTitle;

  /// No description provided for @botWebhookUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Вебхук обновлён'**
  String get botWebhookUpdated;

  /// No description provided for @botWebhookDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Вебхук удалён'**
  String get botWebhookDeleted;

  /// No description provided for @botWebhookUseRailwayDefault.
  ///
  /// In ru, this message translates to:
  /// **'Подставить тестовый URL (Railway)'**
  String get botWebhookUseRailwayDefault;
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
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
