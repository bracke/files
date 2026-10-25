separate (Files_Suite.Interaction)
   procedure Test_Breadcrumb_Segments_And_Elide (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;

      --  A configuration constant, so the comparison is static: always False
      --  on Linux and macOS, always True on Windows.
      pragma Warnings (Off, "condition is always False");
      pragma Warnings (Off, "condition is always True");
      function Running_On_Windows return Boolean is
        (Files_Config.Alire_Host_OS = "windows");
      pragma No_Inline (Running_On_Windows);
      pragma Warnings (On, "condition is always True");
      pragma Warnings (On, "condition is always False");
   begin
      declare
         Segs : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
           Files.Breadcrumbs.Segments ("/home/user/files");
      begin
         Files_Suite.Support.Assert_Equal
           (Natural (Segs.Length),
            3,
            "an absolute path yields one segment per named component (no root)");
         Files_Suite.Support.Assert_Equal
           (To_String (Segs.Element (1).Label),
            "home",
            "the first segment is the first component");
         Files_Suite.Support.Assert_Equal
           (To_String (Segs.Element (1).Ancestor_Path),
            "/home",
            "the first segment navigates to /home");
         Files_Suite.Support.Assert_Equal
           (To_String (Segs.Element (2).Label),
            "user",
            "the second segment is the next component");
         Files_Suite.Support.Assert_Equal
           (To_String (Segs.Element (2).Ancestor_Path),
            "/home/user",
            "the second segment navigates to /home/user");
         Files_Suite.Support.Assert_Equal
           (To_String (Segs.Element (3).Label),
            "files",
            "the last segment is the leaf component");
         Files_Suite.Support.Assert_Equal
           (To_String (Segs.Element (3).Ancestor_Path),
            "/home/user/files",
            "the leaf segment navigates to the full path");
      end;

      if Running_On_Windows then
         declare
            Drive_Path : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
              Files.Breadcrumbs.Segments ("C:\Users\Alice");
            UNC_Path : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
              Files.Breadcrumbs.Segments ("\\server\share\folder");
         begin
            Assert
              (Natural (Drive_Path.Length) = 3
               and then To_String (Drive_Path.Last_Element.Ancestor_Path) =
                 "C:\Users\Alice",
               "Windows drive breadcrumbs retain native separators");
            Files_Suite.Support.Assert_Equal
              (Natural (UNC_Path.Length), 3,
               "UNC breadcrumb click targets retain their two-separator root (segment count)");
            Files_Suite.Support.Assert_Equal
              (To_String (UNC_Path.First_Element.Ancestor_Path), "\\server",
               "UNC breadcrumb click targets retain their two-separator root (first target)");
            Files_Suite.Support.Assert_Equal
              (To_String (UNC_Path.Last_Element.Ancestor_Path), "\\server\share\folder",
               "UNC breadcrumb click targets retain their two-separator root (last target)");
         end;
      else
         declare
            Backslash_Name : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
              Files.Breadcrumbs.Segments ("/tmp/a\b");
         begin
            Files_Suite.Support.Assert_Equal
              (Natural (Backslash_Name.Length), 2,
               "POSIX breadcrumbs keep backslashes inside a filename (segment count)");
            Files_Suite.Support.Assert_Equal
              (To_String (Backslash_Name.Last_Element.Label), "a\b",
               "POSIX breadcrumbs keep backslashes inside a filename (last label)");
            Files_Suite.Support.Assert_Equal
              (To_String (Backslash_Name.Last_Element.Ancestor_Path), "/tmp/a\b",
               "POSIX breadcrumbs keep backslashes inside a filename (last target)");
         end;
      end if;

      declare
         Long   : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
           Files.Breadcrumbs.Segments ("/a/b/c/d/e/f/g");
         Elided : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
           Files.Breadcrumbs.Elide (Long, 4);
         Has_Ellipsis : Boolean := False;
      begin
         Files_Suite.Support.Assert_Equal (Natural (Long.Length), 7, "the long path has seven segments");
         Files_Suite.Support.Assert_Equal (Natural (Elided.Length), 4, "eliding to four keeps four segments");
         Files_Suite.Support.Assert_Equal
           (To_String (Elided.First_Element.Label),
            "a",
            "elision keeps the first component");
         Files_Suite.Support.Assert_Equal
           (To_String (Elided.Last_Element.Label),
            "g",
            "elision keeps the trailing component");
         for S of Elided loop
            if Files.Breadcrumbs.Is_Ellipsis (S) then
               Has_Ellipsis := True;
            end if;
         end loop;
         Assert (Has_Ellipsis, "elision inserts a non-navigable marker between the head and tail");
      end;
   end Test_Breadcrumb_Segments_And_Elide;
