<?php
// Sunovabit contact form handler (runs on Bluehost's PHP).
// Receives the form on contact/index.html and emails it to TO_EMAIL.
// The address below lives only on the server; visitors never see it.

const TO_EMAIL   = 'acluffiii@icloud.com';
// Must be an address at your own domain, or mail providers may reject the message.
// It doesn't need to be a real mailbox.
const FROM_EMAIL = 'no-reply@sunovabit.com';
const SITE_NAME  = 'Sunovabit';

const TOPICS = [
    'general'  => 'General question',
    'dentdog'  => 'DentDOG PDR',
    'mowmoney' => 'Mow Money',
    'preload'  => 'Preload',
    'custom'   => 'Custom project / business inquiry',
    'launch'   => 'Mow Money launch list',
];
const MAX_PER_HOUR = 5;

function go(string $where): void {
    header('Location: ' . $where, true, 303);
    exit;
}

function fail(string $code): void {
    go('index.html?error=' . $code . '#form');
}

// One line of text: no line breaks (blocks email header injection), trimmed, length-capped.
function one_line($value, int $max): string {
    $value = is_string($value) ? $value : '';
    $value = trim(preg_replace('/[\r\n\t\x00-\x1F\x7F]+/', ' ', $value));
    return mb_substr($value, 0, $max, 'UTF-8');
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    go('index.html');
}

// Spam trap: real people never see or fill the hidden "website" field.
if (!empty($_POST['website'])) {
    go('thanks.html');
}

$name     = one_line($_POST['name'] ?? '', 100);
$email    = one_line($_POST['email'] ?? '', 200);
$device   = one_line($_POST['device'] ?? '', 120);
$topicKey = is_string($_POST['topic'] ?? null) ? $_POST['topic'] : 'general';
$topic    = TOPICS[$topicKey] ?? TOPICS['general'];
$message  = is_string($_POST['message'] ?? null) ? $_POST['message'] : '';
$message  = trim(str_replace(["\r\n", "\r"], "\n", $message));
$message  = mb_substr(preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', '', $message), 0, 5000, 'UTF-8');

if ($name === '' || $email === '' || mb_strlen($message, 'UTF-8') < 10) {
    fail('missing');
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    fail('email');
}
if (preg_match_all('#https?://|www\.#i', $message) > 3) {
    fail('links');
}

// Rate limit: at most MAX_PER_HOUR messages per visitor (IP address) per hour.
$ip   = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
$file = sys_get_temp_dir() . '/sunovabit-contact-' . hash('sha256', $ip);
$now  = time();
$hits = [];
if (is_file($file)) {
    foreach (explode(',', (string) @file_get_contents($file)) as $t) {
        if ((int) $t > $now - 3600) {
            $hits[] = (int) $t;
        }
    }
}
if (count($hits) >= MAX_PER_HOUR) {
    fail('rate');
}

$subject = '[' . SITE_NAME . '] ' . $topic . ': ' . $name;
$body = "New message from the sunovabit.com contact form\n\n"
      . "Name:   $name\n"
      . "Email:  $email\n"
      . "Topic:  $topic\n"
      . ($device !== '' ? "Device: $device\n" : '')
      . "\n------------------------------\n"
      . $message
      . "\n------------------------------\n\n"
      . "Hit Reply to answer $name directly.\n"
      . 'Sent ' . gmdate('Y-m-d H:i') . " UTC from IP $ip\n";

$headers = implode("\r\n", [
    'From: ' . SITE_NAME . ' Website <' . FROM_EMAIL . '>',
    'Reply-To: ' . $email,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: 8bit',
]);
$encodedSubject = '=?UTF-8?B?' . base64_encode($subject) . '?=';

if (!mail(TO_EMAIL, $encodedSubject, $body, $headers, '-f' . FROM_EMAIL)) {
    fail('send');
}

$hits[] = $now;
@file_put_contents($file, implode(',', $hits), LOCK_EX);

go('thanks.html');
