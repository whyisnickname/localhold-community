// SPDX-License-Identifier: MPL-2.0

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'localhold_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class LocalholdLocalizationsRu extends LocalholdLocalizations {
  LocalholdLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Localhold';

  @override
  String get navVault => 'Хранилище';

  @override
  String get navSubscriptions => 'Подписки';

  @override
  String get navSecurity => 'Безопасность';

  @override
  String get navSettings => 'Настройки';

  @override
  String get actionAdd => 'Добавить';

  @override
  String get actionSearch => 'Поиск';

  @override
  String get actionLock => 'Заблокировать';

  @override
  String get actionRetry => 'Попробовать снова';

  @override
  String get actionContinueOffline => 'Продолжить офлайн';

  @override
  String get valueHidden => 'Скрытое значение';

  @override
  String get stateEmptyTitle => 'Пока здесь пусто';

  @override
  String get stateOfflineLocalAvailable =>
      'Офлайн — локальные функции доступны';

  @override
  String get stateDiskFull =>
      'Не удалось сохранить: на устройстве недостаточно места';

  @override
  String get stateReadOnly =>
      'Хранилище открыто только для чтения, чтобы защитить данные';

  @override
  String get stateExpired => 'Free включён. Существующие данные доступны.';

  @override
  String get stateLocked =>
      'Разблокируйте локальное хранилище, чтобы продолжить';

  @override
  String get premiumTrialCta => 'Попробовать Premium 14 дней';

  @override
  String get premiumContinueFree => 'Продолжить с Free';

  @override
  String get onboardingLocalVault => 'Создать локальное хранилище';

  @override
  String get privacyStrictOffline => 'Строгий офлайн-режим';

  @override
  String get commonUnavailable => 'Эта функция недоступна в текущей сборке';

  @override
  String get onboardingTrustTitle => 'Ваши данные остаются на этом устройстве';

  @override
  String get onboardingTrustBody =>
      'Localhold не видит ваше хранилище, мастер-пароль, слова восстановления и файлы.';

  @override
  String get onboardingImport => 'Импортировать данные';

  @override
  String get onboardingAccountSecondary => 'Использовать аккаунт для Premium';

  @override
  String get onboardingMasterTitle => 'Создайте мастер-пароль';

  @override
  String get onboardingMasterBody =>
      'Используйте не менее 15 символов. Localhold не сможет восстановить этот пароль.';

  @override
  String get onboardingVaultName => 'Название хранилища';

  @override
  String get onboardingMasterPassword => 'Мастер-пароль';

  @override
  String get onboardingShowNameLocked =>
      'Показывать это название до разблокировки';

  @override
  String get onboardingRecoveryTitle => 'Создайте слова восстановления';

  @override
  String get onboardingRecoveryBody =>
      'Сохраните их в надёжном месте. Это единственный способ вернуть доступ, если вы забудете мастер-пароль.';

  @override
  String get onboardingRecoveryStart => 'Показать слова восстановления';

  @override
  String get onboardingRecoverySkip => 'Пропустить сейчас';

  @override
  String get onboardingRecoveryWarning =>
      'Без слов восстановления забытый мастер-пароль означает потерю доступа к хранилищу.';

  @override
  String onboardingRecoveryChallenge(int position) {
    return 'Введите слово $position';
  }

  @override
  String get onboardingRecoveryConfirm => 'Подтвердить слова восстановления';

  @override
  String get onboardingBiometricTitle =>
      'Использовать разблокировку устройства?';

  @override
  String get onboardingBiometricBody =>
      'Биометрия необязательна. Мастер-пароль продолжит работать.';

  @override
  String get onboardingBiometricEnable => 'Включить биометрию';

  @override
  String get onboardingBiometricSkip => 'Не сейчас';

  @override
  String get onboardingCompleteTitle => 'Локальное хранилище готово';

  @override
  String get onboardingAddFirst => 'Добавить первую запись';

  @override
  String get onboardingOpenVault => 'Открыть хранилище';

  @override
  String get unlockTitle => 'Разблокировка хранилища';

  @override
  String get unlockPassword => 'Мастер-пароль';

  @override
  String get unlockAction => 'Разблокировать';

  @override
  String get unlockBiometric => 'Использовать биометрию';

  @override
  String get unlockRecovery => 'Восстановить доступ';

  @override
  String get unlockChooseVault => 'Выбрать хранилище';

  @override
  String unlockNeutralVault(int ordinal) {
    return 'Хранилище $ordinal';
  }

  @override
  String get unlockCooldown => 'Слишком много попыток. Повторите позже.';

  @override
  String get homeSafetyTitle => 'Состояние безопасности';

  @override
  String get homeSafetyReady =>
      'Восстановление и разблокировка устройства настроены';

  @override
  String get homeSafetyRecoveryMissing =>
      'Создайте слова восстановления для защиты доступа';

  @override
  String get homeQuickFilters => 'Быстрые фильтры';

  @override
  String get homeTypes => 'Типы записей';

  @override
  String get homeRecents => 'Недавние записи';

  @override
  String get homeNoRecents => 'Недавние записи появятся здесь';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get accessInvalidInput => 'Проверьте введённые данные';

  @override
  String get accessInvalidCredentials => 'Мастер-пароль введён неверно';

  @override
  String get accessIntegrityFailure => 'Хранилище нельзя безопасно открыть';

  @override
  String get accessUnknownFailure =>
      'Что-то пошло не так. Существующие данные не изменены.';

  @override
  String get recoveryUnlockTitle => 'Восстановление доступа';

  @override
  String get recoveryUnlockBody =>
      'Введите слова восстановления и задайте новый мастер-пароль.';

  @override
  String get recoveryUnlockPhrase => 'Слова восстановления';

  @override
  String get recoveryUnlockNewPassword => 'Новый мастер-пароль';

  @override
  String get recoveryUnlockAction => 'Восстановить и разблокировать';

  @override
  String get typePickerTitle => 'Выберите тип записи';

  @override
  String get typePickerSearch => 'Поиск по типам записей';

  @override
  String get typePickerRecent => 'Недавно использованные';

  @override
  String get typePickerNoResults => 'Типы записей не найдены';

  @override
  String get typePickerCustom => 'Создать свой тип';

  @override
  String get premiumBadge => 'Premium';

  @override
  String get templateCategoryAccounts => 'Аккаунты';

  @override
  String get templateCategoryMoney => 'Деньги';

  @override
  String get templateCategoryPersonal => 'Личное';

  @override
  String get templateCategoryTechnical => 'Техническое';

  @override
  String get templateAccount => 'Аккаунт';

  @override
  String get templateSocialProfile => 'Социальная сеть';

  @override
  String get templateEmailAccount => 'Почтовый аккаунт';

  @override
  String get templateGamingAccount => 'Игровой аккаунт';

  @override
  String get templateSubscription => 'Подписка';

  @override
  String get templatePaymentCard => 'Банковская карта';

  @override
  String get templateBankDetails => 'Банковские реквизиты';

  @override
  String get templateIdentity => 'Личный контакт';

  @override
  String get templateIdentityDocument => 'Паспорт или документ';

  @override
  String get templateSecureNote => 'Защищённая заметка';

  @override
  String get templateSoftwareLicense => 'Лицензия программы';

  @override
  String get templateWirelessNetwork => 'Сеть Wi-Fi';

  @override
  String get templateRouter => 'Роутер';

  @override
  String get templateServer => 'Сервер или хостинг';

  @override
  String get templateDatabase => 'База данных';

  @override
  String get templateApiCredential => 'Ключ или токен API';

  @override
  String get templateSshCredential => 'Ключ SSH или сертификат';

  @override
  String get templateRecoveryCodes => 'Коды восстановления';

  @override
  String get templateCryptoAccount => 'Криптовалютный аккаунт';

  @override
  String get editorCreateTitle => 'Новая запись';

  @override
  String get editorEditTitle => 'Изменить запись';

  @override
  String get editorAdvanced => 'Дополнительные сведения';

  @override
  String get editorDraftSaving => 'Сохраняем черновик…';

  @override
  String get editorDraftSaved => 'Черновик сохранён';

  @override
  String get editorDraftFailed => 'Черновик не сохранён. Попробуйте ещё раз.';

  @override
  String get editorDraftConflict =>
      'Запись изменилась в другом месте, поэтому сохранён отдельный черновик.';

  @override
  String get editorSaveRecord => 'Сохранить запись';

  @override
  String get editorSaveDraft => 'Сохранить черновик';

  @override
  String get editorContinueEditing => 'Продолжить редактирование';

  @override
  String get editorDeleteDraft => 'Удалить черновик';

  @override
  String get editorBackTitle => 'Сохранить изменения?';

  @override
  String get editorBackBody =>
      'Выберите, что сделать с этим зашифрованным локальным черновиком.';

  @override
  String get editorDeleteFieldTitle => 'Удалить это поле?';

  @override
  String get editorDeleteFieldBody =>
      'В поле есть значение. Удаление можно отменить до сохранения записи.';

  @override
  String get editorRemoveField => 'Удалить поле';

  @override
  String get editorUndo => 'Отменить';

  @override
  String get editorOneValueRequired => 'Введите значение хотя бы в одно поле.';

  @override
  String get editorAddTotp => 'Добавить одноразовый пароль';

  @override
  String get editorAddAttachment => 'Добавить файл или изображение';

  @override
  String get editorAddCustomField => 'Добавить своё поле';

  @override
  String get editorPremiumRequired =>
      'Для добавления этого элемента нужен Premium.';

  @override
  String get recordViewEdit => 'Изменить';

  @override
  String get recordViewReveal => 'Показать';

  @override
  String get recordViewHide => 'Скрыть';

  @override
  String get recordViewCopy => 'Копировать';

  @override
  String get recordViewDelete => 'Удалить навсегда';

  @override
  String get recordViewEmpty => 'В этой записи нет видимых значений.';

  @override
  String get conversionTitle => 'Изменить тип записи';

  @override
  String get conversionMapped => 'Переносится';

  @override
  String get conversionUnmapped => 'Сохранится как дополнительное поле';

  @override
  String get conversionIncompatible =>
      'Несовместимо — сохранится как дополнительное поле';

  @override
  String get conversionApply => 'Применить конвертацию';

  @override
  String get totpImportTitle => 'Добавить одноразовый пароль';

  @override
  String get totpUriOrSecret => 'Ссылка TOTP или секрет Base32';

  @override
  String get totpIssuer => 'Сервис';

  @override
  String get totpAccount => 'Аккаунт';

  @override
  String get totpReview => 'Проверьте перед добавлением';

  @override
  String get totpInvalid => 'Это некорректное значение TOTP.';

  @override
  String get totpAdd => 'Добавить в черновик';

  @override
  String get totpScanQr => 'Сканировать QR-код';

  @override
  String get totpImportQrImage => 'Прочитать QR с изображения';

  @override
  String get totpAlgorithm => 'Алгоритм';

  @override
  String get totpDigits => 'Количество цифр';

  @override
  String get totpPeriod => 'Период';

  @override
  String get actionReview => 'Проверить';

  @override
  String get attachmentFile => 'Выбрать файл';

  @override
  String get attachmentPhoto => 'Выбрать фото';

  @override
  String get attachmentCamera => 'Сделать фото';

  @override
  String get attachmentPermissionDenied =>
      'Доступ запрещён. Его можно включить в настройках системы.';

  @override
  String get attachmentUnavailable => 'Этот источник недоступен на устройстве.';

  @override
  String get attachmentImportFailed =>
      'Файл не добавлен. Частичное вложение не сохранено.';

  @override
  String get attachmentImporting => 'Шифруем на устройстве…';

  @override
  String get attachmentCancel => 'Отменить импорт';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get warningDoNotStoreCardPin =>
      'Не храните PIN карты без реальной необходимости и никому его не сообщайте.';

  @override
  String get warningLocalholdNotWallet =>
      'Localhold не является криптовалютным кошельком. Хранение данных восстановления здесь несёт дополнительный риск.';

  @override
  String get vaultAllRecords => 'Все записи';

  @override
  String get vaultSearch => 'Поиск по записям';

  @override
  String get vaultSearchProtected => 'Искать в защищённых полях';

  @override
  String get vaultSearchProtectedActive => 'Защищённый поиск включён';

  @override
  String get vaultSearchProtectedHint =>
      'После проверки поиск сможет находить пароли, токены и другие защищённые поля. Значения в результатах останутся скрыты.';

  @override
  String get vaultSearchAuthorizationDenied =>
      'Проверка не завершена. Защищённый поиск не включён.';

  @override
  String get vaultNoRecords => 'В этом представлении нет подходящих записей.';

  @override
  String get vaultLoadFailed =>
      'Не удалось загрузить записи. Сохранённые данные не изменились.';

  @override
  String get vaultTryAgain => 'Повторить';

  @override
  String get vaultLayoutCompact => 'Компактный список';

  @override
  String get vaultLayoutComfortable => 'Обычный список';

  @override
  String get vaultLayoutGrid => 'Сетка';

  @override
  String get vaultSortNewest => 'Сначала недавно изменённые';

  @override
  String get vaultSortOldest => 'Сначала давно изменённые';

  @override
  String get vaultSortTitleAsc => 'Название А–Я';

  @override
  String get vaultSortTitleDesc => 'Название Я–А';

  @override
  String get vaultFilterAll => 'Активные';

  @override
  String get vaultFilterFavorites => 'Избранное';

  @override
  String get vaultFilterPinned => 'Закреплённые';

  @override
  String get vaultFilterArchive => 'Архив';

  @override
  String get vaultFilterTrash => 'Корзина';

  @override
  String get vaultFavorite => 'В избранном';

  @override
  String get vaultPinned => 'Закреплено';

  @override
  String get vaultFolder => 'Папка';

  @override
  String get vaultAnyFolder => 'Любая папка';

  @override
  String get vaultTags => 'Теги';

  @override
  String vaultSelected(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get vaultBulkMove => 'Переместить';

  @override
  String get vaultBulkTags => 'Теги';

  @override
  String get vaultBulkFavorite => 'В избранное';

  @override
  String get vaultBulkArchive => 'В архив';

  @override
  String get vaultBulkTrash => 'В корзину';

  @override
  String get vaultBulkExport => 'Экспорт выбранного';

  @override
  String get vaultRestore => 'Восстановить';

  @override
  String get vaultTrashRetention =>
      'Записи хранятся в корзине 30 дней, после чего их можно удалить навсегда.';

  @override
  String get vaultStorageActionFailed =>
      'Изменение не сохранено. Существующие записи остались в безопасности.';

  @override
  String get vaultExportFailed => 'Экспорт не запущен. Записи не изменились.';

  @override
  String get organizationTitle => 'Папки и теги';

  @override
  String get organizationFolders => 'Папки';

  @override
  String get organizationTags => 'Теги';

  @override
  String get organizationAddFolder => 'Добавить папку';

  @override
  String get organizationAddTag => 'Добавить тег';

  @override
  String get organizationName => 'Название';

  @override
  String get organizationRename => 'Переименовать';

  @override
  String get organizationMove => 'Переместить';

  @override
  String get organizationMerge => 'Объединить с другим тегом';

  @override
  String get organizationDelete => 'Удалить';

  @override
  String get organizationDeleteFolderHint =>
      'Вложенные папки и записи перейдут в родительскую папку. Ни одна запись не удалится.';

  @override
  String get organizationDeleteTagHint =>
      'Тег исчезнет из записей. Ни одна запись не удалится.';

  @override
  String get organizationEmpty => 'Папок и тегов пока нет.';

  @override
  String get organizationSaveFailed =>
      'Изменение не сохранено. Предыдущая организация осталась доступна.';

  @override
  String get duplicatesTitle => 'Возможные дубли';

  @override
  String get duplicatesScan => 'Проверить записи';

  @override
  String get duplicatesProtectedScan => 'Сравнить защищённые значения';

  @override
  String get duplicatesProtectedBadge => 'Защищённое сравнение включено';

  @override
  String get duplicatesEmpty => 'Возможные дубли не найдены.';

  @override
  String get duplicatesIntro =>
      'Localhold сравнивает записи только на этом устройстве. Совпадение — подсказка, а не доказательство.';

  @override
  String get duplicatesPossible => 'Возможное совпадение';

  @override
  String get duplicatesLikely => 'Вероятное совпадение';

  @override
  String get duplicatesConflict => 'Конфликтная копия';

  @override
  String get duplicatesConflictHint =>
      'Обе версии сохранены. Сравните их и выберите нужные значения: приложение не назначает правильную версию автоматически.';

  @override
  String get duplicatesReasonTitle => 'одинаковое название';

  @override
  String get duplicatesReasonDomain => 'одинаковый домен сайта';

  @override
  String get duplicatesReasonUsername => 'одинаковое имя пользователя';

  @override
  String get duplicatesReasonEmail => 'одинаковая почта';

  @override
  String get duplicatesReasonIdentifier => 'одинаковый идентификатор';

  @override
  String get duplicatesReasonProtected => 'точно совпало защищённое значение';

  @override
  String get duplicatesReasonConflict => 'сохранено как конфликтная копия';

  @override
  String get duplicatesUseFirst => 'Первая — основная';

  @override
  String get duplicatesUseSecond => 'Вторая — основная';

  @override
  String get mergeTitle => 'Сравнение и объединение';

  @override
  String get mergeTarget => 'Оставить запись';

  @override
  String get mergeSource => 'Переместить в корзину';

  @override
  String get mergeChooseEach =>
      'Для каждого поля выберите значение. Защищённые значения останутся скрытыми.';

  @override
  String get mergeFromTarget => 'Из оставляемой записи';

  @override
  String get mergeFromSource => 'Из другой записи';

  @override
  String mergeResult(String target, String source) {
    return 'Выбранные значения сохранятся в «$target». «$source» переместится в корзину, откуда её можно восстановить.';
  }

  @override
  String get mergeAction => 'Объединить';

  @override
  String get mergeConfirmTitle => 'Объединить эти записи?';

  @override
  String get mergeConfirmBody =>
      'Оставляемая запись обновится, а другая перейдёт в корзину одной локальной операцией.';

  @override
  String get mergeCancel => 'Вернуться к кандидатам';

  @override
  String get mergeFailed =>
      'Ничего не изменено. Обе прежние записи остались доступны.';

  @override
  String get duplicatesAuthorizationDenied =>
      'Защищённое сравнение не включено.';

  @override
  String get reminderTitle => 'Напоминание';

  @override
  String get reminderWhen => 'Когда напомнить';

  @override
  String get reminderDayOf => 'В этот день';

  @override
  String get reminderOneDay => 'За 1 день';

  @override
  String get reminderThreeDays => 'За 3 дня';

  @override
  String get reminderSevenDays => 'За 7 дней';

  @override
  String get reminderCustomOffset => 'Другой срок';

  @override
  String get reminderDaysBefore => 'За сколько дней';

  @override
  String get reminderCustomRange => 'От 0 до 365 дней';

  @override
  String get reminderTime => 'Время напоминания';

  @override
  String get reminderQuietHours => 'Тихие часы';

  @override
  String get reminderQuietStart => 'Начало тихих часов';

  @override
  String get reminderQuietEnd => 'Конец тихих часов';

  @override
  String get reminderPrivacy => 'Данные в уведомлении';

  @override
  String get reminderPrivacyHint =>
      'Секреты и защищённые значения никогда не показываются в уведомлении.';

  @override
  String get reminderPrivate => 'Приватно';

  @override
  String get reminderPrivateHint =>
      'Показывается только нейтральное напоминание Localhold.';

  @override
  String get reminderName => 'Показывать название записи';

  @override
  String get reminderNameAmount => 'Показывать название и безопасную сумму';

  @override
  String get reminderEnable => 'Включить напоминание';

  @override
  String get reminderPermissionTitle => 'Разрешение на уведомления';

  @override
  String get reminderPermissionBody =>
      'Localhold нужно системное разрешение, чтобы показать это напоминание. По умолчанию уведомление нейтральное и не содержит данных записи. Настройку можно изменить позже.';

  @override
  String get reminderContinue => 'Перейти к системному разрешению';

  @override
  String get reminderWorking => 'Сохраняем и планируем напоминание…';

  @override
  String get reminderScheduled =>
      'Напоминание запланировано на этом устройстве.';

  @override
  String get reminderPermissionDenied =>
      'Напоминание сохранено, но выключено: доступ к уведомлениям запрещён.';

  @override
  String get reminderPermissionRestricted =>
      'Напоминание сохранено, но выключено: уведомления ограничены на этом устройстве.';

  @override
  String get reminderPast => 'Это время уже прошло. Выберите время в будущем.';

  @override
  String get reminderFailed =>
      'Напоминание не запланировано. Запись не изменилась.';

  @override
  String get reminderOpenSettings => 'Открыть настройки системы';

  @override
  String get shareInboxTitle => 'Передано в Localhold';

  @override
  String get shareInboxEmpty => 'Нет элементов, ожидающих импорта.';

  @override
  String get shareImportFailed =>
      'Элемент не импортирован. Частичный черновик не сохранён.';

  @override
  String get shareKindText => 'Переданный текст';

  @override
  String get shareKindUrl => 'Переданная ссылка';

  @override
  String get shareKindFile => 'Переданный файл';

  @override
  String get shareKindImage => 'Переданное изображение';

  @override
  String shareBytes(int count) {
    return '$count байт';
  }

  @override
  String get shareProtectedHint =>
      'Содержимое остаётся в защищённом хранилище устройства и станет зашифрованным черновиком только после импорта.';

  @override
  String get shareImport => 'Импортировать в зашифрованный черновик';

  @override
  String get shareDiscard => 'Удалить';
}
