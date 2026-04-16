// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get save => 'Сохранить';

  @override
  String get retry => 'Повторить';

  @override
  String get close => 'Закрыть';

  @override
  String get error => 'Ошибка';

  @override
  String get ok => 'OK';

  @override
  String get copied => 'Скопировано';

  @override
  String get idCopied => 'ID скопирован';

  @override
  String get unknown => 'Неизвестный';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get notifications => 'Уведомления';

  @override
  String get conversations => 'Беседы';

  @override
  String get messageRequests => 'Запросы сообщений';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get appLock => 'Блокировка приложения';

  @override
  String get help => 'Помощь';

  @override
  String get helpInDevelopment => 'Раздел помощи в разработке';

  @override
  String get inviteFriend => 'Пригласить друга';

  @override
  String inviteText(String login) {
    return 'Присоединяйся к Demos! Мой логин: $login';
  }

  @override
  String get regenerateKeys => 'Пересоздать ключи шифрования';

  @override
  String get keysUpdated => 'Ключи шифрования обновлены';

  @override
  String get logout => 'Выйти';

  @override
  String get logoutTitle => 'Выход';

  @override
  String get logoutConfirm => 'Вы уверены, что хотите выйти?';

  @override
  String get clearAllData => 'Очистить все данные';

  @override
  String get clearAllDataConfirm =>
      'Это действие необратимо. Все ваши данные будут безвозвратно удалены.';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get copyId => 'Скопировать ID';

  @override
  String get shareId => 'Поделиться';

  @override
  String myIdInDemos(String id) {
    return 'Мой ID в Demos: $id';
  }

  @override
  String get appVersion => 'Demos Chat 1.0.3 — Сквозное шифрование (E2EE)';

  @override
  String get language => 'Язык';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

  @override
  String avatarNameLabel(String name) {
    return 'Имя аватара: $name';
  }

  @override
  String get editProfileTitle => 'Редактировать профиль';

  @override
  String get yourId => 'Ваш ID';

  @override
  String get idDescription =>
      'Уникальный идентификатор для поиска и транзакций. Нельзя изменить.';

  @override
  String get nickname => 'Ник';

  @override
  String get nicknameHint => 'Только русские буквы';

  @override
  String get nicknameDescription => 'Отображаемое имя. Должен быть уникальным.';

  @override
  String get aiAgentName => 'Имя для ИИ-агента';

  @override
  String get aiNameHint => 'Имя для ИИ и Телепатии';

  @override
  String get aiNameDescription =>
      'Используется в функциях ИИ-агента и Телепатии.';

  @override
  String get aboutYou => 'О себе';

  @override
  String get aboutHint => 'Расскажите немного о себе';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get profileUpdated => 'Профиль обновлён';

  @override
  String get errorSaving => 'Ошибка при сохранении';

  @override
  String get nickCannotBeEmpty => 'Ник не может быть пустым';

  @override
  String get pickFromGallery => 'Выбрать из галереи';

  @override
  String get takePhoto => 'Сделать фото';

  @override
  String get deletePhoto => 'Удалить фото';

  @override
  String get photoUploadFailed => 'Не удалось загрузить фото';

  @override
  String get photoUrlFailed => 'Не удалось получить URL загруженного фото';

  @override
  String get tabMessages => 'Сообщения';

  @override
  String get tabCalls => 'Звонки';

  @override
  String get tabTelepathy => 'Телепатия';

  @override
  String get tabSettings => 'Настройки';

  @override
  String get searchHint => 'Поиск...';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get darkThemeMenu => 'Тёмная тема';

  @override
  String get lightThemeMenu => 'Светлая тема';

  @override
  String get wallet => 'Кошелёк';

  @override
  String get markAsRead => 'Пометить прочитанным';

  @override
  String get clearHistory => 'Очистить историю';

  @override
  String get failedToLoadChats => 'Не удалось загрузить чаты';

  @override
  String get noChatsYet => 'Чатов пока нет';

  @override
  String get findContactViaSearch => 'Найдите собеседника через поиск';

  @override
  String get chatsSection => 'Чаты';

  @override
  String get usersSection => 'Пользователи';

  @override
  String get foundById => 'Найден по ID';

  @override
  String get foundByAvatarName => 'Найден по имени аватара';

  @override
  String get foundByNickname => 'Найден по нику';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get failedToLoadCalls => 'Не удалось загрузить историю звонков';

  @override
  String get noCallsYet => 'Звонков пока нет';

  @override
  String get callHistoryHere => 'Здесь будет история ваших звонков';

  @override
  String get videoCall => 'Видеозвонок';

  @override
  String get audioCall => 'Аудиозвонок';

  @override
  String get group => 'Группа';

  @override
  String get noMessagesPreview => 'Сообщений пока нет';

  @override
  String get voiceMessage => 'Голосовое сообщение';

  @override
  String get photo => 'Фото';

  @override
  String get video => 'Видео';

  @override
  String get attachment => 'Вложение';

  @override
  String get encryptedMessage => 'Зашифрованное сообщение';

  @override
  String get telepathy => 'Телепатия';

  @override
  String get members => 'уч.';

  @override
  String get pinTooltip => 'Закрепить';

  @override
  String get muteTooltip => 'Без звука';

  @override
  String get deleteTooltip => 'Удалить';

  @override
  String get messageHint => 'Сообщение...';

  @override
  String get monthJanuary => 'января';

  @override
  String get monthFebruary => 'февраля';

  @override
  String get monthMarch => 'марта';

  @override
  String get monthApril => 'апреля';

  @override
  String get monthMay => 'мая';

  @override
  String get monthJune => 'июня';

  @override
  String get monthJuly => 'июля';

  @override
  String get monthAugust => 'августа';

  @override
  String get monthSeptember => 'сентября';

  @override
  String get monthOctober => 'октября';

  @override
  String get monthNovember => 'ноября';

  @override
  String get monthDecember => 'декабря';

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get reply => 'Ответить';

  @override
  String get copyText => 'Копировать';

  @override
  String get forward => 'Переслать';

  @override
  String get pin => 'Закрепить';

  @override
  String get unpin => 'Открепить';

  @override
  String get edit => 'Редактировать';

  @override
  String get deleteMsg => 'Удалить';

  @override
  String get editMessage => 'Редактировать сообщение';

  @override
  String get forwardMessage => 'Переслать сообщение';

  @override
  String selectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get messageForwarded => 'Сообщение переслано';

  @override
  String get groupE2eeTitle => 'Групповое сквозное шифрование';

  @override
  String get groupE2eeDescription =>
      'В этой группе используется протокол Sender Keys.\nКаждый участник генерирует свой ключ,\nи все сообщения шифруются так, что только\nучастники группы могут их прочитать.';

  @override
  String membersWithE2ee(int count) {
    return '$count участник с E2EE';
  }

  @override
  String get clearHistoryTitle => 'Очистить историю';

  @override
  String get clearHistoryConfirm =>
      'Вы уверены, что хотите очистить историю у всех?';

  @override
  String get clear => 'Очистить';

  @override
  String get deleteChatTitle => 'Удалить чат';

  @override
  String get deleteChatConfirm => 'Вы уверены, что хотите удалить этот чат?';

  @override
  String typingStatus(String name) {
    return '$name печатает...';
  }

  @override
  String get typing => 'печатает...';

  @override
  String get online => 'в сети';

  @override
  String get offline => 'не в сети';

  @override
  String get searchInChat => 'Поиск по чату...';

  @override
  String get errorLoadingMessages => 'Ошибка загрузки сообщений';

  @override
  String get noMessagesYet => 'Сообщений пока нет';

  @override
  String get enableNotifications => 'Включить уведомления';

  @override
  String get disableNotifications => 'Выключить уведомления';

  @override
  String get encryption => 'Шифрование';

  @override
  String get clearHistoryAll => 'Очистить историю у всех';

  @override
  String get deleteChat => 'Удалить чат';

  @override
  String get groupInfo => 'Инфо о группе';

  @override
  String get pinnedMessage => 'Закреплённое сообщение';

  @override
  String get you => 'Вы';

  @override
  String get fileUploadError => 'Ошибка загрузки файла';

  @override
  String get micPermissionError => 'Нет доступа к микрофону';

  @override
  String get voiceUploadError => 'Ошибка загрузки голосового';

  @override
  String get voiceSendError => 'Ошибка отправки голосового';

  @override
  String get trustBannerTitle => 'Доверять этому пользователю?';

  @override
  String get trustBannerDescription =>
      'Если оба собеседника подтвердят доверие, откроются полные профили (имя, аватар, фото).';

  @override
  String get trustNo => 'Нет';

  @override
  String get trustYes => 'Доверяю';

  @override
  String membersCount(int count) {
    return '$count участник';
  }

  @override
  String get profileTitle => 'Профиль';

  @override
  String get userFallback => 'Пользователь';

  @override
  String userBlocked(String name) {
    return '$name заблокирован';
  }

  @override
  String userUnblocked(String name) {
    return '$name разблокирован';
  }

  @override
  String get blockError => 'Ошибка при блокировке';

  @override
  String blockConfirmTitle(String name) {
    return 'Заблокировать $name?';
  }

  @override
  String get blockConfirmMessage =>
      'Заблокированный пользователь не сможет отправлять вам сообщения и видеть ваш профиль.';

  @override
  String get block => 'Заблокировать';

  @override
  String get userNotFound => 'Пользователь не найден';

  @override
  String get info => 'Информация';

  @override
  String get trustNotConfirmed => 'Доверие не подтверждено';

  @override
  String get writeMessage => 'Написать';

  @override
  String get callAction => 'Позвонить';

  @override
  String get videoCallAction => 'Видео';

  @override
  String get muteSound => 'Без звука';

  @override
  String get unmuteSound => 'Вкл звук';

  @override
  String get mediaFiles => 'Медиафайлы';

  @override
  String get viewAll => 'Все →';

  @override
  String get noMediaFiles => 'Нет медиафайлов';

  @override
  String get allMedia => 'Все медиа';

  @override
  String get blockUser => 'Заблокировать';

  @override
  String get unblockUser => 'Разблокировать';

  @override
  String get settingSaveError => 'Не удалось сохранить настройку';

  @override
  String get voiceVideoBeta => 'Голос и видео (Бета)';

  @override
  String get voiceVideoCalls => 'Голосовые и видеозвонки';

  @override
  String get allowCalls => 'Разрешить входящие и исходящие звонки';

  @override
  String get screenSecurity => 'Безопасность экрана';

  @override
  String get lockApp => 'Заблокировать приложение';

  @override
  String get lockAppDescription =>
      'Использовать Touch ID, Face ID или пароль устройства для входа в Demos';

  @override
  String get readReceipts => 'Отчеты о прочтении';

  @override
  String get readReceiptsDescription =>
      'Отправлять отчеты о прочтении в личных чатах';

  @override
  String get typingIndicators => 'Индикаторы набора текста';

  @override
  String get typingIndicatorsDescription =>
      'Видеть и показывать, когда кто-то печатает';

  @override
  String get linkPreviews => 'Предпросмотр ссылок';

  @override
  String get linkPreviewsDescription =>
      'Создавать превью для поддерживаемых ссылок';

  @override
  String get strategy => 'Стратегия';

  @override
  String get fastMode => 'Быстрый режим';

  @override
  String get fastModeDescription =>
      'Мгновенные уведомления через серверы Google';

  @override
  String get systemSettings => 'Системные настройки';

  @override
  String get systemSettingsDescription => 'Настройки уведомлений устройства';

  @override
  String get styleSection => 'Стиль';

  @override
  String get sound => 'Звук';

  @override
  String get soundDefault => 'По умолчанию';

  @override
  String get soundNone => 'Без звука';

  @override
  String get soundSystem => 'Системный';

  @override
  String get vibration => 'Вибрация';

  @override
  String get vibDefault => 'По умолчанию';

  @override
  String get vibShort => 'Короткая';

  @override
  String get vibLong => 'Длинная';

  @override
  String get vibOff => 'Отключена';

  @override
  String get popup => 'Всплывающее окно';

  @override
  String get popupAlways => 'Всегда';

  @override
  String get popupScreenOn => 'Только при включённом экране';

  @override
  String get popupNever => 'Никогда';

  @override
  String get inAppSound => 'Звук в приложении';

  @override
  String get inAppSoundDescription =>
      'Воспроизводить звук, когда приложение открыто';

  @override
  String get contentSection => 'Содержимое';

  @override
  String get notificationContent => 'Содержимое уведомлений';

  @override
  String get contentNameAndText => 'Имя и текст';

  @override
  String get contentNameOnly => 'Только имя';

  @override
  String get contentHidden => 'Без содержимого';

  @override
  String get mediaPreview => 'Предпросмотр медиа';

  @override
  String get mediaPreviewDescription =>
      'Показывать фото и видео в уведомлениях';

  @override
  String get exceptions => 'Исключения';

  @override
  String get doNotDisturb => 'Режим «Не беспокоить»';

  @override
  String get doNotDisturbDescription =>
      'Не показывать уведомления в определённое время';

  @override
  String get notificationSound => 'Звук уведомлений';

  @override
  String get popupNotification => 'Всплывающее уведомление';

  @override
  String get create => 'Создать';

  @override
  String get groupName => 'Название группы';

  @override
  String get groupDescriptionOptional => 'Описание (необязательно)';

  @override
  String get searchByNameOrId => 'Поиск по имени или ID...';

  @override
  String get enterGroupName => 'Введите название группы';

  @override
  String get foundByName => 'Найден по имени';

  @override
  String get idUser => 'ID пользователь';

  @override
  String get messageCleanup => 'Очистка сообщений';

  @override
  String get communityCleanup => 'Очистка сообществ';

  @override
  String get communityCleanupDescription =>
      'Удалять сообщения из сообществ старше 6 месяцев или если их более 2000';

  @override
  String get enterKey => 'Клавиша Enter';

  @override
  String get enterSends => 'Отправка клавишей Enter';

  @override
  String get enterSendsDescription =>
      'Нажатие клавиши Enter отправит ваше сообщение';

  @override
  String get voiceMessages => 'Голосовые сообщения';

  @override
  String get autoPlay => 'Автовоспроизведение';

  @override
  String get autoPlayDescription =>
      'Автоматически воспроизводить сообщения по очереди';

  @override
  String get blockedContacts => 'Заблокированные контакты';

  @override
  String get theme => 'Тема';

  @override
  String get accentColor => 'Акцентный цвет';

  @override
  String get chatWallpaper => 'Фон чата';

  @override
  String get systemTheme => 'Системная тема';

  @override
  String get followSystem => 'Как в системе';

  @override
  String unblockConfirm(String name) {
    return 'Разблокировать $name?';
  }

  @override
  String get contactUnblocked => 'Контакт разблокирован';

  @override
  String get noBlockedContacts => 'Нет заблокированных контактов';

  @override
  String get blockedContactsHint =>
      'Заблокированные вами контакты\nпоявятся здесь';

  @override
  String get requestAccepted => 'Запрос принят';

  @override
  String get acceptError => 'Ошибка при принятии';

  @override
  String get requestDeclinedBlocked =>
      'Запрос отклонён, пользователь заблокирован';

  @override
  String get requestDeclined => 'Запрос отклонён';

  @override
  String get declineError => 'Ошибка при отклонении';

  @override
  String get decline => 'Отклонить';

  @override
  String get declineAndBlock => 'Отклонить и заблокировать';

  @override
  String get clearAllRequests => 'Очистить все';

  @override
  String get clearAllRequestsConfirm =>
      'Вы уверены, что хотите отклонить все запросы сообщений?';

  @override
  String get declineAll => 'Отклонить все';

  @override
  String get allRequestsDeclined => 'Все запросы отклонены';

  @override
  String get clearRequestsError => 'Ошибка при очистке';

  @override
  String get noRequests => 'Запросов нет';

  @override
  String get noRequestsHint => 'Запросы от новых контактов появятся здесь';

  @override
  String get noMessages => 'Нет сообщений';

  @override
  String get accept => 'Принять';

  @override
  String get e2eeTitle => 'Сквозное шифрование';

  @override
  String e2eeDescription(String name) {
    return 'Сообщения в этом чате защищены сквозным шифрованием. Только вы и $name можете читать их.';
  }

  @override
  String get securityCode => 'Код безопасности';

  @override
  String securityCodeHint(String name) {
    return 'Сравните этот код с кодом у $name, чтобы убедиться в безопасности чата.';
  }

  @override
  String get copyCode => 'Копировать код';

  @override
  String get codeCopied => 'Код скопирован';

  @override
  String get securityCodeUnavailable =>
      'Код безопасности станет доступен после обмена сообщениями.';

  @override
  String get wallpaperLove => 'Любовь';

  @override
  String get wallpaperStarwars => 'Star Wars';

  @override
  String get wallpaperDoodles => 'Дудлы';

  @override
  String get wallpaperMath => 'Математика';

  @override
  String get wallpaperCosmos => 'Космос';

  @override
  String get wallpaperNone => 'Без фона';

  @override
  String get myBots => 'Мои боты';

  @override
  String get createBot => 'Создать бота';

  @override
  String get botName => 'Имя бота';

  @override
  String get botUsername => 'Имя пользователя бота';

  @override
  String get botDescription => 'Описание';

  @override
  String get botDescriptionHint => 'Что делает этот бот?';

  @override
  String get botAvatar => 'Аватар';

  @override
  String get botWebhookUrl => 'URL вебхука';

  @override
  String get botWebhookHint => 'https://example.com/webhook';

  @override
  String get botToken => 'Токен бота';

  @override
  String get botTokenCopied => 'Токен скопирован';

  @override
  String get botRegenerateToken => 'Пересоздать токен';

  @override
  String get botRegenerateTokenConfirm =>
      'Сгенерировать новый токен? Старый перестанет работать.';

  @override
  String get botSetWebhook => 'Установить вебхук';

  @override
  String get botDeleteWebhook => 'Удалить вебхук';

  @override
  String get botDelete => 'Удалить бота';

  @override
  String get botDeleteConfirm =>
      'Вы уверены, что хотите удалить бота? Это действие необратимо.';

  @override
  String get botCreated => 'Бот создан';

  @override
  String get botUpdated => 'Бот обновлён';

  @override
  String get botDeleted => 'Бот удалён';

  @override
  String get botActive => 'Активен';

  @override
  String get botInactive => 'Неактивен';

  @override
  String get botToggleActive => 'Вкл/Выкл бота';

  @override
  String get noBots => 'Ботов пока нет';

  @override
  String get noBotsHint => 'Создайте своего первого бота';

  @override
  String get botNameRequired => 'Имя бота обязательно';

  @override
  String get botUsernameRequired => 'Имя пользователя бота обязательно';

  @override
  String get botBadge => 'БОТ';

  @override
  String get botEditTitle => 'Редактировать бота';

  @override
  String get botWebhookUpdated => 'Вебхук обновлён';

  @override
  String get botWebhookDeleted => 'Вебхук удалён';

  @override
  String get botWebhookUseRailwayDefault => 'Подставить тестовый URL (Railway)';
}
