<?php

namespace App\Support;

use DOMDocument;
use DOMElement;
use DOMNode;

final class RichTextSanitizer
{
    private const ALLOWED_TAGS = [
        'a', 'blockquote', 'br', 'em', 'figcaption', 'figure', 'h2', 'h3', 'h4',
        'hr', 'i', 'img', 'li', 'ol', 'p', 'strong', 'table', 'tbody', 'td',
        'th', 'thead', 'tr', 'u', 'ul',
    ];

    private const DROP_WITH_CONTENT_TAGS = ['script', 'style', 'iframe', 'object', 'embed', 'link', 'meta'];

    public static function clean(?string $html): ?string
    {
        $html = trim((string) $html);
        if ($html === '') {
            return null;
        }

        $previous = libxml_use_internal_errors(true);
        $document = new DOMDocument('1.0', 'UTF-8');
        $document->loadHTML(
            '<?xml encoding="UTF-8"><!DOCTYPE html><html><body>'.$html.'</body></html>',
            LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD
        );
        libxml_clear_errors();
        libxml_use_internal_errors($previous);

        $body = $document->getElementsByTagName('body')->item(0);
        if (! $body) {
            return null;
        }

        self::cleanChildren($body);

        $output = '';
        foreach ($body->childNodes as $child) {
            $output .= $document->saveHTML($child);
        }

        $output = trim($output);

        return $output !== '' ? $output : null;
    }

    private static function cleanChildren(DOMNode $node): void
    {
        foreach (iterator_to_array($node->childNodes) as $child) {
            if (! $child instanceof DOMElement) {
                continue;
            }

            $tag = strtolower($child->tagName);
            if (in_array($tag, self::DROP_WITH_CONTENT_TAGS, true)) {
                $node->removeChild($child);

                continue;
            }

            self::cleanChildren($child);

            if (! in_array($tag, self::ALLOWED_TAGS, true)) {
                self::unwrapElement($child);

                continue;
            }

            self::cleanAttributes($child, $tag);
        }
    }

    private static function unwrapElement(DOMElement $element): void
    {
        $parent = $element->parentNode;
        if (! $parent) {
            return;
        }

        while ($element->firstChild) {
            $parent->insertBefore($element->firstChild, $element);
        }

        $parent->removeChild($element);
    }

    private static function cleanAttributes(DOMElement $element, string $tag): void
    {
        foreach (iterator_to_array($element->attributes) as $attribute) {
            $name = strtolower($attribute->nodeName);
            $value = trim($attribute->nodeValue ?? '');

            if (str_starts_with($name, 'on') || $name === 'style') {
                $element->removeAttributeNode($attribute);

                continue;
            }

            if (! self::attributeAllowed($tag, $name)) {
                $element->removeAttributeNode($attribute);

                continue;
            }

            if ($name === 'href' && ! self::safeLink($value)) {
                $element->removeAttributeNode($attribute);

                continue;
            }

            if ($name === 'src' && ! self::safeImage($value)) {
                $element->removeAttributeNode($attribute);
            }
        }

        if ($tag === 'a' && $element->hasAttribute('href')) {
            $element->setAttribute('rel', 'noopener noreferrer');
            if (self::externalLink($element->getAttribute('href'))) {
                $element->setAttribute('target', '_blank');
            }
        }
    }

    private static function attributeAllowed(string $tag, string $name): bool
    {
        $allowed = match ($tag) {
            'a' => ['href', 'title', 'target', 'rel'],
            'img' => ['src', 'alt', 'title', 'width', 'height'],
            'td', 'th' => ['colspan', 'rowspan'],
            default => ['title'],
        };

        return in_array($name, $allowed, true);
    }

    private static function safeLink(string $value): bool
    {
        $lower = strtolower($value);

        return str_starts_with($value, '#')
            || str_starts_with($value, '/')
            || str_starts_with($lower, 'http://')
            || str_starts_with($lower, 'https://')
            || str_starts_with($lower, 'mailto:')
            || str_starts_with($lower, 'tel:');
    }

    private static function safeImage(string $value): bool
    {
        $path = parse_url($value, PHP_URL_PATH) ?: '';

        return str_starts_with($value, '/api/public/homepage/rich-text-images/')
            || str_starts_with($path, '/api/public/homepage/rich-text-images/');
    }

    private static function externalLink(string $value): bool
    {
        $lower = strtolower($value);

        return str_starts_with($lower, 'http://') || str_starts_with($lower, 'https://');
    }
}
