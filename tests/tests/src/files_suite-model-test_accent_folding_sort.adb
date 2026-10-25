separate (Files_Suite.Model)
   procedure Test_Accent_Folding_Sort (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function F (S : String) return String renames Files.Types.Fold_For_Sort;

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

      --  Plain ASCII is just lower-cased, and a script with no Latin base is
      --  preserved rather than dropped.
      Files_Suite.Support.Assert_Equal (F ("HELLO.txt"), "hello.txt", "ASCII is lower-cased");
      Files_Suite.Support.Assert_Equal
        (F (Character'Val (16#CE#) & Character'Val (16#A9#)),
         Character'Val (16#CE#) & Character'Val (16#A9#),
         "a non-Latin codepoint keeps its own bytes");
   end Test_Accent_Folding_Sort;
