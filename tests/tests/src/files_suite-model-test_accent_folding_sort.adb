with Guikit.Utf8;
with Files.Text_Case;

separate (Files_Suite.Model)
   procedure Test_Accent_Folding_Sort (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function F (S : String) return String renames Files.Text_Case.Fold_For_Sort;
      function U (Codepoint : Natural) return String renames Guikit.Utf8.Encode;

      --  UTF-8 bytes, spelt out so the test does not depend on how the source
      --  encoding treats a literal. C3 84 = U+00C4 A-umlaut, C3 9F = sharp-s,
      --  C3 A9 = e-acute.
      Umlaut_A : constant String := Character'Val (16#C3#) & Character'Val (16#84#);
      Sharp_S  : constant String := Character'Val (16#C3#) & Character'Val (16#9F#);
      E_Acute  : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);

      A_Umlaut_Name : constant String := Umlaut_A & "pfel";      --  "Äpfel"
      Sharp_Name    : constant String := "Stra" & Sharp_S & "e"; --  "Straße"
      Acute_Name    : constant String := "caf" & E_Acute;        --  "café"
   begin
      --  The accented letter folds to its base, so the key collates with the
      --  base letter rather than after all of a..z (the raw-byte-order bug).
      Files_Suite.Support.Assert_Equal (F (A_Umlaut_Name), "apfel", "an umlaut folds to its base letter");
      Files_Suite.Support.Assert_Equal (F (A_Umlaut_Name), F ("Apfel"), "accented and plain names share a fold key");
      Assert (F (A_Umlaut_Name) < F ("Bericht"), "the umlaut name sorts before Bericht");
      Assert
        (F (A_Umlaut_Name) < F ("Zebra"),
         "the umlaut name sorts before Zebra, not after every a..z name");
      Files_Suite.Support.Assert_Equal (F (Sharp_Name), "strasse", "sharp-s folds to ss");
      Files_Suite.Support.Assert_Equal
        (F (Sharp_Name),
         F ("Strasse"),
         "strasse and its sharp-s spelling share a fold key");
      Files_Suite.Support.Assert_Equal (F (Acute_Name), "cafe", "an acute accent folds to the base letter");

      --  Plain ASCII is just lower-cased, and a script with no Latin base
      --  folds case within itself rather than being dropped.
      Files_Suite.Support.Assert_Equal (F ("HELLO.txt"), "hello.txt", "ASCII is lower-cased");
      Files_Suite.Support.Assert_Equal (F (U (16#3A9#)), U (16#3C9#), "a Greek capital folds to its lower case");

      --  A name stored decomposed (e and a combining acute, as macOS and SMB
      --  servers write it) sorts as the same name stored composed, not after
      --  every other name: ecole (NFC), ezra, ecole (NFD) must not split.
      Files_Suite.Support.Assert_Equal
        (F ("e" & U (16#301#) & "cole"), F (E_Acute & "cole"), "a decomposed accent folds like a composed one");
      Assert (F ("e" & U (16#301#) & "cole") < F ("ezra"), "a decomposed name sorts beside its base letter");

      --  Cyrillic and Greek fold case, so capitals do not all come first:
      --  banan, Vishnya, yabloko, Apelsin sort as apelsin, banan, vishnya, yabloko.
      declare
         Apelsin : constant String := U (16#410#) & U (16#43F#) & U (16#435#);
         Banan   : constant String := U (16#431#) & U (16#430#) & U (16#43D#);
         Vishnya : constant String := U (16#412#) & U (16#438#) & U (16#448#);
         Yabloko : constant String := U (16#44F#) & U (16#431#) & U (16#43B#);
      begin
         Assert (F (Apelsin) < F (Banan) and then F (Banan) < F (Vishnya) and then F (Vishnya) < F (Yabloko),
                 "Cyrillic names sort by letter whatever their case");
         Files_Suite.Support.Assert_Equal
           (F (U (16#419#) & "x"), F (U (16#438#) & U (16#306#) & "x"),
            "a composed Cyrillic short i folds like its decomposed form");
      end;
      Files_Suite.Support.Assert_Equal
        (F (U (16#3AC#)), F (U (16#3B1#) & U (16#301#)), "a Greek tonos folds whichever way it is stored");
      --  Polytonic Greek: breathings, accents and iota subscript fold away,
      --  in either case, as the decomposed spelling's marks do.
      Files_Suite.Support.Assert_Equal
        (F (U (16#1F00#) & U (16#1F38#) & U (16#1FF3#)), F (U (16#3B1#) & U (16#3B9#) & U (16#3C9#)),
         "polytonic Greek letters fold to their base letters");
      Files_Suite.Support.Assert_Equal
        (F (U (16#1FEC#) & U (16#1F21#)), F (U (16#3C1#) & U (16#3B7#) & U (16#314#)),
         "a polytonic capital folds like its decomposed lower case");

      --  Vietnamese letters and their decomposed spellings share a key.
      Files_Suite.Support.Assert_Equal (F ("Vi" & U (16#1EC7#) & "t"), "viet", "a Vietnamese letter folds to its base");
      Files_Suite.Support.Assert_Equal
        (F (U (16#1A1#) & "n"), F ("o" & U (16#31B#) & "n"), "o with horn folds like o and a combining horn");

      --  Korean stored as jamo composes into its syllable, and a voiced kana
      --  stored as kana plus a voicing mark folds like the composed one.
      Files_Suite.Support.Assert_Equal
        (F (U (16#1112#) & U (16#1161#) & U (16#11AB#)), U (16#D55C#), "Hangul jamo compose into their syllable");
      Files_Suite.Support.Assert_Equal
        (F (U (16#304C#)), F (U (16#304B#) & U (16#3099#)), "a voiced kana folds whichever way it is stored");
      Files_Suite.Support.Assert_Equal
        (F (U (16#30D1#)), F (U (16#30CF#) & U (16#309A#)), "a half-voiced katakana folds whichever way it is stored");

      --  Bytes that are not UTF-8 are kept, not dropped.
      Files_Suite.Support.Assert_Equal
        (F ("A" & Character'Val (16#FF#) & "B"), "a" & Character'Val (16#FF#) & "b", "a stray byte is kept as it is");
   end Test_Accent_Folding_Sort;
