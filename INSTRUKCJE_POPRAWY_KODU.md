# Division2WatchFace — instrukcje poprawy kodu

Dokument roboczy do przeprowadzenia refaktoryzacji tarczy zegarka (Garmin Connect IQ / Monkey C) na podstawie przeglądu kodu. Ma służyć jako lista zadań do odhaczania podczas pracy z Claude Code.

**Projekt:** `W:\VAULT\Zegarek\Division2WatchFace`
**Pliki źródłowe:** `source/*.mc`

---

## 1. Krytyczne (blokują kompilację)

### 1.1 Brakująca stała `COLOR_SHD_HEX_OUTER`
- **Plik:** `source/DivisionTheme.mc`, metoda `drawBackground()`
- **Problem:** stała `COLOR_SHD_HEX_OUTER` jest użyta, ale nigdzie niezadeklarowana (zadeklarowane są tylko `COLOR_SHD_ORANGE`, `COLOR_SHD_AMBER`, `COLOR_SHD_RUST`, `COLOR_SHD_HEX_MID`, `COLOR_SHD_DIM`, `COLOR_SHD_SEMI`). Kompilator Monkey C zgłosi błąd „undefined symbol”.
- **Do zrobienia:** dodać brakującą stałą obok pozostałych `private const`, np. ciemniejszy odcień pomarańczu do zewnętrznej obwódki heksagonów (np. `0x1A0800`), i upewnić się, że jest spójna kolorystycznie z resztą palety SHD.

---

## 2. Wydajność (priorytet wysoki — realny wpływ na baterię)

### 2.1 Brak buforowania statycznej grafiki (`BufferedBitmap` / offscreen buffer)
- **Dotyczy:** wszystkich motywów (`DivisionTheme`, `DuneTheme`, `BlackFlagTheme`, `WarhammerTheme`), metody `drawBackground()` i `drawOuterRing()`.
- **Problem:** `onUpdate()` jest wywoływane co sekundę w trybie aktywnym, a mimo to cała statyczna grafika (siatka heksagonalna, pierścienie, znaczniki godzin, wzory tła) jest przeliczana i rysowana od zera przy każdej klatce. Szczególnie kosztowna jest siatka heksagonalna w `DivisionTheme.drawBackground()` — zagnieżdżona pętla z `sin/cos` i 6× `drawLine` na każdy heksagon.
- **Do zrobienia:**
  - Wprowadzić `Graphics.createBufferedBitmap()` (lub `Graphics.BufferedBitmap`) per motyw — narysować tło + pierścień + znaczniki **raz** (przy `loadResources()` lub pierwszym `onUpdate` po zmianie motywu) do bufora, a w `onUpdate()` tylko `dc.drawBitmap()` tego bufora.
  - Dynamiczne elementy (czas, data, bateria, progres kroków, pola danych) rysować normalnie na wierzchu bufora, bo się zmieniają.

### 2.2 Trygonometria liczona w pętli co klatkę zamiast raz
- **Dotyczy:** `drawOuterRing()` w każdym motywie (pętle po 12/24/60 znacznikach z `Math.cos`/`Math.sin` w środku pętli).
- **Do zrobienia:** przenieść obliczanie kątów/punktów do `init()` (raz na uruchomienie/inicjalizację motywu) i zapisać gotowe współrzędne w tablicy (np. `_tickPoints as Array`). W `onUpdate()` tylko odczytywać gotowe wartości. To naturalnie łączy się z pkt. 2.1 — najlepiej całość (tło + pierścień) od razu renderować do bufora.

### 2.3 Wielokrotne odczyty ustawień (`getProp`) w każdej klatce
- **Plik:** `source/ThemeBase.mc`, metoda `drawDataFields()`
- **Problem:** `getProp("FieldTopLeft", ...)` itd. wywoływane 4× w każdym `onUpdate()`, mimo że wartości zmieniają się tylko wtedy, gdy użytkownik zmieni ustawienia w Garmin Connect.
- **Do zrobienia:** wczytać wartości pól raz w `onSettingsChanged()` (i raz na starcie) do zmiennych instancyjnych, a `drawDataFields()` niech korzysta z już wczytanych wartości.

---

## 3. Spójność i jakość kodu

### 3.1 Brak adnotacji typów w plikach motywów
- **Dotyczy:** `DivisionTheme.mc`, `BlackFlagTheme.mc`, `DuneTheme.mc`, `WarhammerTheme.mc` — metody typu `function drawBackground(dc)` zamiast `public function drawBackground(dc as Graphics.Dc) as Void`.
- **Problem:** `ThemeBase.mc` konsekwentnie używa pełnych typów (Monkey C type checker), pozostałe pliki nie — traci się część korzyści statycznego typowania i spójność stylu.
- **Do zrobienia:** ujednolicić sygnatury wszystkich nadpisanych metod do pełnych adnotacji typów zgodnie z `ThemeBase`.

### 3.2 Magiczne liczby zamiast stałych/enumów
- **Dotyczy:** typy pól danych (1–7) w `getFieldDataStr()`, indeksy motywów (0–3) w `getThemeIndex()`.
- **Do zrobienia:** wprowadzić nazwane stałe, np. `FIELD_WEATHER = 1`, `FIELD_ALTITUDE = 2` itd. oraz `THEME_DUNE = 0`, `THEME_DIVISION = 1` itd. Poprawia to czytelność i ułatwia przyszłe zmiany (np. dodanie nowego pola danych).

### 3.3 Podwójne czyszczenie ekranu w `WarhammerTheme`
- **Plik:** `source/WarhammerTheme.mc`, metody `drawBackground()` i `drawAOD()`
- **Problem:** obie metody same wywołują `dc.setColor(...COLOR_BLACK); dc.clear();`, mimo że `Division2WatchFaceView.onUpdate()` już czyści ekran przed wywołaniem theme. Redundantna operacja.
- **Do zrobienia:** usunąć zbędne `dc.clear()` z `WarhammerTheme`, chyba że jest tam celowo dla innego efektu — wtedy dodać komentarz wyjaśniający dlaczego.

---

## 4. Sugestie opcjonalne (nice-to-have)

- Rozważyć dodanie prostych testów/skryptu weryfikującego (np. lint pod kątem nieużywanych/niezadeklarowanych symboli) przed każdym buildem, żeby uniknąć błędów jak w pkt. 1.1.
- Rozważyć wydzielenie wspólnej logiki rysowania znaczników godzin (60 tick marks) do jednej metody w `ThemeBase`, parametryzowanej kolorami/promieniami — obecnie każdy motyw ma bardzo podobny, powielony kod.
- Udokumentować w komentarzu na górze `Division2WatchFaceView.mc`, że godziny przełączania motywów (8/12/17/22) są celowe i gdzie je zmienić, jeśli użytkownik zechce inny rozkład.

---

## 5. Sekcja „Kod” — jak przeprowadzić to w Claude Code

Poniżej proponowany proces pracy z wykorzystaniem Claude Code (CLI) do wdrożenia powyższych poprawek w sposób kontrolowany, zamiast jednego dużego, nieprzewidywalnego promptu.

### 5.1 Przygotowanie sesji
1. Otwórz terminal w katalogu projektu: `cd W:\VAULT\Zegarek\Division2WatchFace`.
2. Upewnij się, że kod jest pod kontrolą wersji (`git init` + pierwszy commit „stan wyjściowy”), jeśli jeszcze nie jest — to pozwoli łatwo cofnąć każdą nieudaną zmianę i zobaczyć diff po każdym kroku.

### 5.2 Tryb planowania — `/plan`
- Zacznij od komendy **`/plan`** i wklej (lub zlinkuj) ten plik jako punkt odniesienia, np.:
  > „Przeanalizuj `INSTRUKCJE_POPRAWY_KODU.md` i zaproponuj plan wdrożenia sekcji 1–3, zaczynając od błędu kompilacji.”
- W trybie planu Claude Code nie modyfikuje jeszcze plików — tylko proponuje kroki. To jest moment, żeby zweryfikować kolejność zmian i zakres, zanim cokolwiek zostanie zmienione w kodzie.
- Zatwierdź plan dopiero, gdy kolejność (1 → 2 → 3) i zakres każdego kroku wygląda sensownie.

### 5.3 Wdrażanie etapami (nie jednym promptem)
Zalecana kolejność, żeby każdy krok dało się łatwo zweryfikować i cofnąć osobno:

1. **Krok 1 — fix kompilacji (sekcja 1.1).** Mały, izolowany, łatwy do zweryfikowania buildem.
2. **Krok 2 — cache ustawień (sekcja 2.3).** Niskie ryzyko regresji wizualnej, dobry „rozgrzewkowy” krok przed trudniejszym bufferingiem.
3. **Krok 3 — buforowanie grafiki (`BufferedBitmap`, sekcja 2.1 + 2.2).** Najbardziej ryzykowna zmiana wizualnie — rób **motyw po motywie** (osobny prompt/commit na `DivisionTheme`, potem `DuneTheme`, `BlackFlagTheme`, `WarhammerTheme`), żeby po każdym module dało się porównać wygląd na symulatorze przed przejściem dalej.
4. **Krok 4 — porządki (sekcja 3.1–3.3).** Czysto kosmetyczne/refaktoryzacyjne, bezpieczne do zrobienia na końcu.

Po każdym kroku:
- Zbuduj projekt w Connect IQ SDK (lub poproś Claude Code o uruchomienie builda, jeśli masz `monkeyc`/`ciq` dostępne w PATH) i sprawdź, że się kompiluje.
- Obejrzyj wynik w symulatorze (`connectiq` / Simulator), zwłaszcza po kroku 3, gdzie zmienia się sposób renderowania tła.
- Zrób commit z opisem, co dokładnie zostało zmienione — ułatwia to ewentualny rollback pojedynczego kroku.

### 5.4 Weryfikacja końcowa
- Na koniec poproś Claude Code o przegląd całościowy (code review) po wszystkich zmianach — najlepiej w nowej, „czystej” sesji/kontekście, żeby przegląd nie był robiony przez tego samego agenta, który pisał kod (mniejsze ryzyko, że przeoczy własne błędy).
- Sprawdź realny wpływ na baterię, jeśli masz taką możliwość (Garmin Connect IQ SDK ma profiler / można porównać czas pracy baterii w symulatorze przed/po zmianach w sekcji 2).

### 5.5 Przydatne komendy/skille do tego procesu
- **`/plan`** — do wstępnego rozbicia dużej zmiany na kroki, zanim cokolwiek zostanie tknięte w kodzie (opisane wyżej).
- Tryb **code review / drugi zestaw oczu** — po zakończeniu każdego większego etapu (zwłaszcza kroku 3) warto poprosić o przegląd zmian pod kątem regresji wizualnych i wydajnościowych, zanim przejdzie się do kolejnego motywu.
- Commitowanie po każdym kroku (opisane w 5.3) pełni rolę „punktu kontrolnego” — jeśli jeden z kroków wprowadzi regresję graficzną, łatwo wrócić do stanu sprzed niego bez utraty wcześniejszych, już zweryfikowanych poprawek.
