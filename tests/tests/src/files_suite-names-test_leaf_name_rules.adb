with Files.File_System.Testing;
separate (Files_Suite.Names)
   procedure Test_Leaf_Name_Rules (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Posix (Name : String) return Boolean is
        (Files.File_System.Valid_Leaf_Name (Name, Files.File_System.Posix_Rules));

      function Win (Name : String) return Boolean is
        (Files.File_System.Valid_Leaf_Name (Name, Files.File_System.Windows_Rules));

      Tab : constant String := "bad" & Character'Val (9) & "name";
   begin
      --  Visible characters, reserved device names and a trailing dot are
      --  ordinary on a POSIX filesystem but forbidden on Windows: accepted under
      --  Posix_Rules, rejected under Windows_Rules. Checked directly so both rule
      --  sets are exercised whichever host runs the suite (Host_Rules resolves to
      --  one or the other and cannot exercise the absent one).
      Assert (Posix ("bad\name.txt"), "POSIX allows a backslash in a name");
      Assert (not Win ("bad\name.txt"), "Windows rejects a backslash in a name");
      Assert (Posix ("my:notes.txt"), "POSIX allows a colon in a name");
      Assert (not Win ("my:notes.txt"), "Windows rejects a colon in a name");
      Assert (Posix ("track01?.flac"), "POSIX allows a wildcard character in a name");
      Assert (not Win ("track01?.flac"), "Windows rejects a wildcard character in a name");
      Assert (Posix ("ch*.txt"), "POSIX allows an asterisk in a name");
      Assert (not Win ("ch*.txt"), "Windows rejects an asterisk in a name");
      Assert (Posix ("a|b.txt") and then Posix ("a<b>.txt"), "POSIX allows pipe and angle brackets");
      Assert (not Win ("a|b.txt") and then not Win ("a<b>.txt"), "Windows rejects pipe and angle brackets");
      Assert (Posix ("aux"), "POSIX allows reserved-device-style names: aux");
      Assert (Posix ("CON.txt"), "POSIX allows reserved-device-style names: CON.txt");
      Assert (Posix ("CONIN$"), "POSIX allows reserved-device-style names: CONIN$");
      Assert (not Win ("aux"), "Windows rejects reserved device names: aux");
      Assert (not Win ("CON.txt"), "Windows rejects reserved device names: CON.txt");
      Assert (not Win ("CONIN$"), "Windows rejects reserved device names: CONIN$");
      --  COM and LPT with any digit, 0 included, or a superscript 1-3, in any
      --  case, with or without an extension.
      for Port in Character range '0' .. '9' loop
         Assert (not Win ("COM" & Port) and then not Win ("lpt" & Port & ".txt"),
                 "Windows rejects the COM and LPT ports numbered " & Port);
      end loop;
      for Superscript of String'(Character'Val (16#B9#), Character'Val (16#B2#), Character'Val (16#B3#)) loop
         declare
            Number : constant String := Character'Val (16#C2#) & Superscript;
         begin
            Assert (not Win ("Com" & Number) and then not Win ("LPT" & Number & ".log"),
                    "Windows rejects the COM and LPT ports numbered with a superscript");
            Assert (Posix ("COM" & Number), "POSIX allows a superscript-numbered port name");
         end;
      end loop;
      Assert (Win ("COM10") and then Win ("LPT") and then Win ("COMA.txt"),
              "only a single digit or superscript makes a port name");
      Assert (Win ("COM" & Character'Val (16#C2#) & Character'Val (16#B4#)),
              "another two-byte character after COM is not a port");
      Assert (Posix ("ends-with-dot."), "POSIX allows a trailing dot");
      Assert (not Win ("ends-with-dot."), "Windows rejects a trailing dot");

      --  A plain filename is valid under every rule set; the confusing or broken
      --  names are rejected under every rule set, host included.
      for Rules in Files.File_System.Name_Rules loop
         Assert
           (Files.File_System.Valid_Leaf_Name ("ordinary-name.txt", Rules),
            "every rule set accepts an ordinary filename");
         Assert
           (not Files.File_System.Valid_Leaf_Name ("", Rules),
            "no rule set accepts an empty name");
         Assert
           (not Files.File_System.Valid_Leaf_Name (".", Rules)
              and then not Files.File_System.Valid_Leaf_Name ("..", Rules),
            "no rule set accepts the special directory entries");
         Assert
           (not Files.File_System.Valid_Leaf_Name ("a/b.txt", Rules),
            "no rule set accepts a path separator");
         Assert
           (not Files.File_System.Valid_Leaf_Name (Tab, Rules),
            "no rule set accepts a control character");
         Assert
           (not Files.File_System.Valid_Leaf_Name ("trailing ", Rules)
              and then not Files.File_System.Valid_Leaf_Name ("   ", Rules),
            "no rule set accepts trailing or all whitespace");
      end loop;

      --  Resolved against a real destination, Valid_Leaf_Name_At follows that
      --  destination's filesystem: a colon name is accepted exactly when the
      --  filesystem holding the directory is not DOS-ruled. This ties the wiring
      --  to Hostkit's detection and holds on any host (POSIX test root -> valid,
      --  a Windows NTFS root -> not), while the universal rejections stand
      --  regardless of the destination.
      Reset_Root;
      declare
         Dos_Root : constant Boolean := Hostkit.Fs.Uses_Dos_Filename_Rules (Root);
      begin
         Assert
           (Files.File_System.Valid_Leaf_Name_At ("my:notes.txt", Root) = not Dos_Root,
            "a colon name is valid at a destination iff its filesystem is not DOS-ruled");
         Assert
           (Files.File_System.Valid_Leaf_Name_At ("ordinary.txt", Root),
            "an ordinary name is valid at any destination");
         Assert
           (not Files.File_System.Valid_Leaf_Name_At ("a/b.txt", Root),
            "a path separator is rejected at any destination");

         --  An existing entry's name, copied or moved, need only be one the
         --  destination can hold: a tab or bytes that are not UTF-8 are
         --  refused for a name typed, kept for a name that is already there.
         declare
            function Storable (Name : String) return Boolean is
              (Files.File_System.Testing.Storable_Leaf_Name_At (Name, Root));
            Not_Utf8 : constant String := Character'Val (16#FF#) & "name.txt";
         begin
            if Dos_Root then
               Assert (Storable ("ordinary.txt") and then not Storable ("my:notes.txt"),
                       "on a DOS-ruled destination the stored name follows its rules");
            else
               Assert (not Files.File_System.Valid_Leaf_Name_At (Tab, Root) and then Storable (Tab),
                       "a tab is refused when typed but kept when moved");
               Assert (Storable (Not_Utf8), "a name that is not UTF-8 is kept when moved");
               Assert (Storable ("notes ") and then Storable ("my:notes.txt"), "any byte but / and NUL is kept");
            end if;
            Assert
              (not Storable ("") and then not Storable (".") and then not Storable ("..")
               and then not Storable ("a/b") and then not Storable ("a" & ASCII.NUL & "b"),
               "no destination holds an empty name, a dot entry, a separator or a NUL");
         end;
      end;
   end Test_Leaf_Name_Rules;
