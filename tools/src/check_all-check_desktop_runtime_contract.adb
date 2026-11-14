separate (Check_All)
   procedure Check_Desktop_Runtime_Contract is
      Windows_Body : constant String := Root & "/src/files-application-windows.adb";
      Tests        : constant String := Combined_Suite;
      Wait_Body    : constant String := Root & "/src/files-application-windows-event_loop_wait.adb";
      Share_Body   : constant String := Root & "/src/files-application-windows-share_settings_from.adb";
      Jobs_Body    : constant String := Root & "/src/files-operation_jobs.adb";

      --  Report Message and fail check_all, as the Require_ guards do.
      procedure Fail (Message : String) with No_Return is
      begin
         Put_Line (Standard_Error, Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      --  How many times Code names Name as a whole name: not as part of a
      --  longer identifier (Drop_Events.Take is not Drop_Events.Take_Overflow).
      function Count_Names (Code : String; Name : String) return Natural is
         From     : Positive := Code'First;
         Found    : Natural := 0;
         At_Index : Natural;
      begin
         while From <= Code'Last loop
            At_Index := Ada.Strings.Fixed.Index (Code (From .. Code'Last), Name);
            exit when At_Index = 0;
            if (At_Index = Code'First or else not Is_Ada_Identifier_Char (Code (At_Index - 1)))
              and then (At_Index + Name'Length > Code'Last
                        or else not Is_Ada_Identifier_Char (Code (At_Index + Name'Length)))
            then
               Found := Found + 1;
            end if;
            From := At_Index + Name'Length;
         end loop;
         return Found;
      end Count_Names;

      --  Whether Code names Name as a whole name.
      function Names (Code : String; Name : String) return Boolean is (Count_Names (Code, Name) > 0);

      --  The code (comments stripped, strings blanked) of the body of the
      --  subprogram Name, wherever in the unit whose body is Base_Path it
      --  lives: the body itself or one of its subunits (<stem>-*.adb), so a
      --  body moved into a subunit is still found -- from the nearest
      --  "procedure Name" or "function Name" before "end Name;". A unit
      --  family where no file has that body fails the check: the guard would
      --  otherwise guard nothing.
      function Subprogram_Code (Base_Path : String; Name : String) return String is
         Dir     : constant String := Ada.Directories.Containing_Directory (Base_Path);
         Prefix  : constant String := Ada.Directories.Base_Name (Base_Path) & "-";
         Suffix  : constant String := ".adb";
         Search  : Ada.Directories.Search_Type;
         Item    : Ada.Directories.Directory_Entry_Type;
         Found   : Unbounded_String;
         Matches : Natural := 0;

         procedure Look_In (Path : String) is
            Code     : constant String :=
              Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True);
            Ending   : constant Natural := Ada.Strings.Fixed.Index (Code, "end " & Name & ";");
            Start    : Natural := 0;

            --  Keep in Start the nearest Header before Ending that is the
            --  whole name, not the start of a longer one.
            procedure Find_Header (Header : String) is
               Last : Natural := Ending;
               Here : Natural;
            begin
               loop
                  Here := Ada.Strings.Fixed.Index (Code (Code'First .. Last), Header, Going => Ada.Strings.Backward);
                  exit when Here = 0;
                  if Here + Header'Length > Code'Last
                    or else not Is_Ada_Identifier_Char (Code (Here + Header'Length))
                  then
                     Start := Natural'Max (Start, Here);
                     exit;
                  end if;
                  exit when Here = Code'First;
                  Last := Here + Header'Length - 2;
               end loop;
            end Find_Header;
         begin
            if Ending = 0 then
               return;
            end if;
            Find_Header ("procedure " & Name);
            Find_Header ("function " & Name);
            if Start /= 0 then
               Matches := Matches + 1;
               Found := To_Unbounded_String (Code (Start .. Ending + Name'Length + 4));
            end if;
         end Look_In;
      begin
         if not Project_Tools.Files.File_Exists (Base_Path) then
            Fail ("guarded file is missing: " & Base_Path & " (looking for the body of " & Name & ")");
         end if;
         Look_In (Base_Path);
         Ada.Directories.Start_Search
           (Search,
            Directory => Dir,
            Pattern   => "*",
            Filter    =>
              [Ada.Directories.Ordinary_File => True,
               Ada.Directories.Directory     => False,
               Ada.Directories.Special_File  => False]);
         begin
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Item);
               declare
                  File_Name : constant String := Ada.Directories.Simple_Name (Item);
               begin
                  if File_Name'Length > Prefix'Length + Suffix'Length
                    and then File_Name (File_Name'First .. File_Name'First + Prefix'Length - 1) = Prefix
                    and then File_Name (File_Name'Last - Suffix'Length + 1 .. File_Name'Last) = Suffix
                  then
                     Look_In (Ada.Directories.Full_Name (Item));
                  end if;
               end;
            end loop;
         exception
            when others =>
               Ada.Directories.End_Search (Search);
               raise;
         end;
         Ada.Directories.End_Search (Search);
         if Matches /= 1 then
            Fail (Base_Path & ": the body of " & Name & " is in" & Natural'Image (Matches)
                  & " files of the unit, not one; the guards on it would not know which to read");
         end if;
         return To_String (Found);
      end Subprogram_Code;

      --  A background job's finish (Advance, on its success path and on its
      --  failure path alike) merges the history the helper journalled into
      --  the window's and then settles it: History_Journal.Restore there
      --  would replace the window's history with the journal's, dropping
      --  entries the journal left out, and an unsettled merge would leave the
      --  payloads of retired entries behind. Restore stays in Run_Helper,
      --  the helper's side, where the journal is the whole history.
      Job_Finish : constant String := Subprogram_Code (Jobs_Body, "Advance");

      --  A window imports its queued drops through
      --  Files.Controller.Import_Pending_Drops, which leaves them queued while
      --  an overlay owns the input; taking them straight from the queue
      --  (Drop_Events.Take) would import them under an open overlay.
      Drop_Input : constant String := Subprogram_Code (Windows_Body, "Handle_Drop_Input");
   begin
      if Count_Names (Job_Finish, "Files.History_Journal.Merge") < 2 then
         Fail (Jobs_Body & ": a background job's finish must merge the helper's history "
               & "(Files.History_Journal.Merge) on its success and its failure path");
      end if;
      if Count_Names (Job_Finish, "Files.Operations.Settle_History") < 2 then
         Fail (Jobs_Body & ": a background job's finish must settle the merged history "
               & "(Files.Operations.Settle_History) on its success and its failure path");
      end if;
      if Ada.Strings.Fixed.Index (Job_Finish, "Files.History_Journal.Merge")
        > Ada.Strings.Fixed.Index (Job_Finish, "Files.Operations.Settle_History")
      then
         Fail (Jobs_Body & ": a background job's finish must settle the history after merging it, not before");
      end if;
      if Names (Job_Finish, "History_Journal.Restore") then
         Fail (Jobs_Body & ": a background job's finish must merge the helper's history, "
               & "not replace the window's with it (History_Journal.Restore)");
      end if;
      if not Names (Drop_Input, "Files.Controller.Import_Pending_Drops") then
         Fail (Windows_Body & ": Handle_Drop_Input must import drops through Files.Controller.Import_Pending_Drops");
      end if;
      if Names (Drop_Input, "Drop_Events.Take") then
         Fail (Windows_Body & ": Handle_Drop_Input must not take drops from the queue itself "
               & "(Drop_Events.Take); Files.Controller.Import_Pending_Drops leaves them queued under an overlay");
      end if;
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glyphs.Missing_Glyph_Count /= 0",
         "headless smoke must not reject otherwise visible frames solely for missing-glyph fallback");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glfw.Windows.Context.Make_Current",
         "desktop Vulkan runtime must not make an OpenGL context current");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glfw.Windows.Context.Swap_Buffers",
         "desktop Vulkan runtime must not swap OpenGL buffers");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glfw.Windows.Context.Set_Swap_Interval",
         "desktop Vulkan runtime must not configure OpenGL swap interval");
      Require_Registered_Routine
        ("Test_Runtime_Capabilities_And_Drop_Events",
         "the test of runtime capabilities and drop events");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Runtime.Last_Missing_Glyph_Count = 0",
         "live smoke must not reject otherwise visible frames solely for missing-glyph fallback");
      --  The window's wiring, in the window's own code (the test suite once
      --  checked these names anywhere in src, which a stale mention passed).
      Require_Contains
        (Windows_Body, "Glfw.Windows.Drop.Paths.Watch", "every window must hand its drops to the import queue");
      Require_Contains
        (Windows_Body, "Handle_Drop_Input", "the event loop must import queued drops");
      Require_Contains (Windows_Body, "Files.Window_Icon.Set", "every window must show the application icon");
      Require_Contains
        (Windows_Body, "Guikit.Vulkan.Wait_For_Events", "the event loop must wait for events, not spin");
      Require_Contains
        (Windows_Body, "Files.Refresh_Jobs.Poll_Watch", "the event loop must poll the folder watch");
      --  The event loop's wait and the cross-window settings sync are decided
      --  by the folds the suite tests (Files.Event_Wait.Fold, and
      --  Files.Settings_Sharing.Share_From with Adopt_Window as its Adopt):
      --  the window subunits only hand them each window's state. A
      --  reimplementation in the subunit would leave the suite testing code
      --  the program no longer runs.
      Require_Contains
        (Wait_Body, "Files.Event_Wait.Fold", "the event loop's wait must be Files.Event_Wait.Fold over the windows");
      Require_Contains
        (Wait_Body, "Event_Wait_Timeout", "the event loop's wait must start the fold from the normal wait");
      Require_Contains
        (Wait_Body, "Mouse_Ready", "the event loop's wait must hand the fold each window's queued mouse change");
      Require_Contains
        (Wait_Body, "Background_Paste", "the event loop's wait must hand the fold each window's background paste");
      Require_Not_Contains
        (Wait_Body,
         "Window_Wait",
         "the event loop's wait must not fold the windows itself; Files.Event_Wait.Fold does");
      Require_Contains
        (Share_Body,
         "Files.Settings_Sharing.Share_From",
         "the settings sync must run Files.Settings_Sharing.Share_From");
      Require_Contains
        (Share_Body,
         "Files.Settings_Sharing.Adopt_Window",
         "a window adopting shared settings must do so through Files.Settings_Sharing.Adopt_Window");
      Require_Not_Contains
        (Share_Body,
         "Adopt_Shared_Settings",
         "a window adopting shared settings must not bypass Files.Settings_Sharing.Adopt_Window");
      Require_Not_Contains
        (Share_Body,
         "Frame_Cache_Valid :=",
         "the frame cache is dropped by Files.Settings_Sharing.Adopt_Window, where the suite sees it");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "inotify",
         "window code must not name a Linux-only facility directly; go through Hostkit.Watch");
   end Check_Desktop_Runtime_Contract;
