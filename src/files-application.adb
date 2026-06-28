with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Interfaces;

with Project_Tools.Files;

with Files.File_System;
with Files.Application.Windows;
with Files_Config;
with Files.Localization;
with Files.Rendering;
with Files.Rendering.Vulkan;

package body Files.Application is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Files.File_System.Path_Status;
   use type Files.Rendering.Text_Render_Status;

   function Parse_Run_Configuration
     (Arguments : String_Vectors.Vector)
      return Run_Configuration
   is
      Result      : Run_Configuration;
      Parse_Flags : Boolean := True;
      Need_Settings_Path : Boolean := False;
   begin
      for Argument of Arguments loop
         declare
            Value : constant String := To_String (Argument);
         begin
            if Need_Settings_Path then
               Result.Settings_Path := Argument;
               Need_Settings_Path := False;
            elsif Parse_Flags and then Value = "--" then
               Parse_Flags := False;
            elsif Parse_Flags and then Value = "--runtime-smoke" then
               Result.Mode := Headless_Smoke_Run;
            elsif Parse_Flags and then Value = "--live-smoke" then
               Result.Mode := Live_Smoke_Run;
            elsif Parse_Flags and then (Value = "--help" or else Value = "-h") then
               Result.Mode := Help_Run;
            elsif Parse_Flags and then Value = "--version" then
               Result.Mode := Version_Run;
            elsif Parse_Flags and then Value = "--settings" then
               Need_Settings_Path := True;
            elsif Parse_Flags
              and then Value'Length >= 11
              and then Value (Value'First .. Value'First + 10) = "--settings="
            then
               if Value'Length = 11 then
                  Result.Settings_Path := Null_Unbounded_String;
               else
                  Result.Settings_Path := To_Unbounded_String (Value (Value'First + 11 .. Value'Last));
               end if;
            else
               Result.Paths.Append (Argument);
            end if;
         end;
      end loop;

      if Need_Settings_Path then
         Result.Paths.Append (To_Unbounded_String ("--settings"));
      end if;

      return Result;
   end Parse_Run_Configuration;

   function Help_Text
     (Locale : String := "en")
      return String
   is
   begin
      return
        Files.Localization.Text ("cli.help.usage", Locale)
        & ASCII.LF
        & Files.Localization.Text ("cli.help.path", Locale)
        & ASCII.LF
        & Files.Localization.Text ("cli.help.option.runtime_smoke", Locale)
        & ASCII.LF
        & Files.Localization.Text ("cli.help.option.live_smoke", Locale)
        & ASCII.LF
        & Files.Localization.Text ("cli.help.option.settings", Locale)
        & ASCII.LF
        & Files.Localization.Text ("cli.help.option.version", Locale)
        & ASCII.LF
        & Files.Localization.Text ("cli.help.option.help", Locale);
   end Help_Text;

   function Version_Text return String is
   begin
      return Files_Config.Crate_Name & " " & Files_Config.Crate_Version;
   end Version_Text;

   function Safe_Environment_Value (Name : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;

      return "";
   exception
      when others =>
         return "";
   end Safe_Environment_Value;

   function Home_Directory return String is
      Home            : constant String := Safe_Environment_Value ("HOME");
      User_Profile    : constant String := Safe_Environment_Value ("USERPROFILE");
      Home_Drive      : constant String := Safe_Environment_Value ("HOMEDRIVE");
      Home_Path       : constant String := Safe_Environment_Value ("HOMEPATH");
      Home_Share      : constant String := Safe_Environment_Value ("HOMESHARE");
      Drive_Profile   : constant String :=
        (if Home_Drive /= "" and then Home_Path /= "" then Home_Drive & Home_Path else "");

      function Existing_Directory (Path : String) return Boolean is
      begin
         return Path /= "" and then Project_Tools.Files.Directory_Exists (Path);
      exception
         when others =>
            return False;
      end Existing_Directory;
   begin
      if Existing_Directory (Home) then
         return Home;
      elsif Existing_Directory (User_Profile) then
         return User_Profile;
      elsif Existing_Directory (Drive_Profile) then
         return Drive_Profile;
      elsif Existing_Directory (Home_Share) then
         return Home_Share;
      else
         return Ada.Directories.Current_Directory;
      end if;
   end Home_Directory;

   function Default_Settings_Path
     (Home_Path : String)
      return String is
   begin
      return
        Files.File_System.Join_Path
          (Files.File_System.Join_Path
             (Files.File_System.Join_Path (Home_Path, ".config"), "files"),
           "settings.conf");
   end Default_Settings_Path;

   function Configured_Settings_Path
     (Home_Path : String)
      return String
   is
      Files_Settings : constant String := Safe_Environment_Value ("FILES_SETTINGS");
      Xdg_Config     : constant String := Safe_Environment_Value ("XDG_CONFIG_HOME");
   begin
      if Files_Settings /= "" then
         return Files_Settings;
      elsif Xdg_Config /= "" then
         return
           Files.File_System.Join_Path
             (Files.File_System.Join_Path (Xdg_Config, "files"),
              "settings.conf");
      else
         return Default_Settings_Path (Home_Path);
      end if;
   end Configured_Settings_Path;

   function Resolve_Startup
     (Arguments     : String_Vectors.Vector;
      Settings_Path : String := "")
      return Startup_Result
   is
      Home           : constant String := Home_Directory;
      Effective_Path : constant String :=
        (if Settings_Path = "" then Configured_Settings_Path (Home) else Settings_Path);
      Settings       : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result         : Startup_Result;
      Resolved       : Startup_Result;
   begin
      declare
         Ensured : constant Files.Settings.Settings_Write_Result :=
           Files.Settings.Ensure_Default_File (Effective_Path);
      begin
         if Ensured.Success then
            declare
               Loaded : constant Files.Settings.Settings_Parse_Result := Files.Settings.Load_File (Effective_Path);
            begin
               if Loaded.Success then
                  Settings := Loaded.Settings;
               else
                  Result.Errors.Append
                    (Startup_Error'
                       (Input_Path => To_Unbounded_String (Effective_Path), Error_Key => Loaded.Error_Key));
               end if;
            end;
         else
            Result.Errors.Append
              (Startup_Error'
                 (Input_Path => To_Unbounded_String (Effective_Path), Error_Key => Ensured.Error_Key));
         end if;
      end;

      Result.Settings := Settings;
      Result.Settings_Path := To_Unbounded_String (Effective_Path);
      Resolved := Resolve_Startup_Paths (Arguments, Settings);
      Result.Windows := Resolved.Windows;
      for Error of Resolved.Errors loop
         Result.Errors.Append (Error);
      end loop;

      return Result;
   end Resolve_Startup;

   --  Map the settings sort enum onto the runtime model's sort enum and
   --  apply the persisted info-pane toggle. Used after Files.Model.Initialize
   --  so every freshly created window reflects the last persisted UI state.
   procedure Apply_Persisted_UI_State
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      Mapped : Files.Model.Sort_Field;
   begin
      case Settings.Sort_Field_Value is
         when Files.Settings.Sort_By_Name     => Mapped := Files.Model.Sort_Name;
         when Files.Settings.Sort_By_Filetype => Mapped := Files.Model.Sort_Type;
         when Files.Settings.Sort_By_Size     => Mapped := Files.Model.Sort_Size;
         when Files.Settings.Sort_By_Created  => Mapped := Files.Model.Sort_Created;
         when Files.Settings.Sort_By_Modified => Mapped := Files.Model.Sort_Changed;
      end case;

      Files.Model.Select_Sort_Field (Model, Mapped);
      if not Settings.Sort_Ascending and then Files.Model.Sort_Is_Ascending (Model) then
         Files.Model.Select_Sort_Field (Model, Mapped);
      end if;
      if Settings.Info_Pane_Open and then not Files.Model.Info_Pane_Is_Open (Model) then
         Files.Model.Toggle_Info_Pane (Model);
      end if;
   end Apply_Persisted_UI_State;

   function Resolve_Startup_Paths
     (Arguments : String_Vectors.Vector;
      Settings  : Files.Settings.Settings_Model)
      return Startup_Result
   is
      Result     : Startup_Result;
      Candidates : String_Vectors.Vector := Arguments;
      Home       : constant String := Home_Directory;

      function Already_Has_Window (Directory_Path : String) return Boolean is
      begin
         for Window of Result.Windows loop
            if To_String (Window.Path) = Directory_Path then
               return True;
            end if;
         end loop;

         return False;
      end Already_Has_Window;
   begin
      Result.Settings := Settings;
      Result.Settings_Path := Null_Unbounded_String;

      if Candidates.Is_Empty then
         Candidates.Append (To_Unbounded_String (Home));
      end if;

      for Argument of Candidates loop
         declare
            Input      : constant String := To_String (Argument);
            Path_Check : constant Files.File_System.Path_Result := Files.File_System.Normalize_Path (Input);
         begin
            if Path_Check.Status = Files.File_System.Path_Valid then
               declare
                  Directory_Path : constant String := To_String (Path_Check.Directory_Path);
               begin
                  if not Already_Has_Window (Directory_Path) then
                     declare
                        Load   : constant Files.File_System.Directory_Load_Result :=
                          Files.File_System.Load_Directory (Directory_Path, Settings);
                        Window : Startup_Window;
                     begin
                        if Load.Success then
                           Files.Model.Initialize
                             (Model             => Window.Model,
                              Directory_Path    => To_String (Load.Path),
                              Items             => Load.Items,
                              Home_Path         => Home,
                              Default_View_Mode => Settings.Default_View);
                           Apply_Persisted_UI_State (Window.Model, Settings);
                           Window.Path := Load.Path;
                           Window.Title := Load.Path;
                           Result.Windows.Append (Window);
                        else
                           Result.Errors.Append
                             (Startup_Error'(Input_Path => To_Unbounded_String (Input), Error_Key => Load.Error_Key));
                        end if;
                     end;
                  end if;
               end;
            else
               Result.Errors.Append
                 (Startup_Error'
                    (Input_Path => To_Unbounded_String (Input), Error_Key => Path_Check.Error_Key));
            end if;
         end;
      end loop;

      return Result;
   end Resolve_Startup_Paths;

   function Startup_Report
     (Result : Startup_Result;
      Locale : String := "en")
      return String
   is
      Report     : Unbounded_String := Null_Unbounded_String;
      First_Line : Boolean := True;

      procedure Append_Line (Line : String) is
      begin
         if First_Line then
            First_Line := False;
         else
            Append (Report, ASCII.LF);
         end if;

         Append (Report, Line);
      end Append_Line;
   begin
      for Window of Result.Windows loop
         Append_Line
           (Files.Localization.Text ("startup.window.ready", Locale) & ": " & To_String (Window.Title));
      end loop;

      for Error of Result.Errors loop
         Append_Line
           (Files.Localization.Text ("startup.error", Locale) & ": "
            & To_String (Error.Input_Path) & ": "
            & Files.Localization.Text (To_String (Error.Error_Key), Locale));
      end loop;

      return To_String (Report);
   end Startup_Report;

   function Desktop_Error_Report
     (Error_Key : String;
      Locale    : String := "en")
      return String
   is
      Effective_Key : constant String := (if Error_Key = "" then "error.window.create" else Error_Key);
      Message       : constant String := Files.Localization.Text (Effective_Key, Locale);
      Fallback      : constant String := Files.Localization.Text ("error.window.create", Locale);
   begin
      return
        Files.Localization.Text ("startup.error", Locale) & ": "
        & (if Message = Effective_Key then Fallback else Message);
   end Desktop_Error_Report;

   function Runtime_Smoke_Report
     (Result : Startup_Result;
      Width  : Natural := 1024;
      Height : Natural := 768;
      Locale : String := "en")
      return String
   is
      Report     : Unbounded_String := Null_Unbounded_String;
      First_Line : Boolean := True;

      function Natural_Text (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Natural_Text;

      procedure Append_Line (Line : String) is
      begin
         if First_Line then
            First_Line := False;
         else
            Append (Report, ASCII.LF);
         end if;

         Append (Report, Line);
      end Append_Line;
   begin
      if Result.Windows.Is_Empty then
         Append_Line (Files.Localization.Text ("runtime.smoke.no_windows", Locale));
         return To_String (Report);
      end if;

      declare
         Quality : constant Files.Application.Windows.Headless_Render_Quality_Result :=
           Files.Application.Windows.Headless_Render_Quality_Report
             (Result,
              Width  => Width,
              Height => Height);
      begin
         Append_Line
           ((if Quality.Passed
             then Files.Localization.Text ("runtime.smoke.ready", Locale)
             else Files.Localization.Text ("runtime.smoke.text_failed", Locale))
            & "  "
            & Files.Localization.Text ("runtime.smoke.frames_attempted", Locale)
            & ": "
            & Natural_Text (Quality.Frame_Count)
            & "  "
            & Files.Localization.Text ("runtime.smoke.frames_presented", Locale)
            & ": "
            & Natural_Text (Quality.Nonblank_Frames)
            & "  "
            & Files.Localization.Text ("runtime.smoke.glyphs", Locale)
            & ": "
            & Natural_Text (Quality.Text_Glyph_Frames)
            & "  "
            & Files.Localization.Text ("runtime.smoke.missing_glyphs", Locale)
            & ": "
            & Natural_Text (Quality.Missing_Glyph_Count));
      end;

      for Window of Result.Windows loop
         declare
            Snapshot      : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Window.Model, Result.Settings);
            Frame         : constant Files.Rendering.Frame_Commands :=
              Files.Rendering.Build_Frame_Commands
                (Snapshot    => Snapshot,
                 Width       => Width,
                 Height      => Height,
                 Line_Height => 20,
                 Hover_X     => 5,
                 Hover_Y     => 5,
                 Has_Hover   => Width > 0 and then Height > 0);
            Text_Renderer : Files.Rendering.Text_Renderer;
            Frame_Font_Path : constant String := Files.Rendering.Font_Path_For_Frame (Frame);
            Text_Status   : constant Files.Rendering.Text_Render_Status :=
              Files.Rendering.Initialize_Text
                (Renderer    => Text_Renderer,
                 Font_Path   => Frame_Font_Path,
                 Pixel_Size  => 16,
                 Cell_Width  => 12,
                 Cell_Height => 20);
            Glyphs        : constant Files.Rendering.Text_Render_Result :=
              Files.Rendering.Build_Text_Glyphs (Text_Renderer, Frame);
            Batch         : constant Files.Rendering.Vulkan.Submission_Batch :=
              Files.Rendering.Vulkan.Build_Submission (Frame, Glyphs);
         begin
            Append_Line
              (Files.Localization.Text ("runtime.smoke.window", Locale)
               & ": "
               & To_String (Window.Title)
               & "  "
               & Files.Localization.Text ("runtime.smoke.rectangles", Locale)
               & ": "
               & Natural_Text (Natural (Frame.Rectangles.Length))
               & "  "
               & Files.Localization.Text ("runtime.smoke.glyphs", Locale)
               & ": "
               & Natural_Text (Natural (Glyphs.Glyphs.Length))
               & "  "
               & Files.Localization.Text ("runtime.smoke.missing_glyphs", Locale)
               & ": "
               & Natural_Text (Glyphs.Missing_Glyph_Count)
               & "  "
               & Files.Localization.Text ("runtime.smoke.font", Locale)
               & ": "
               & Frame_Font_Path
               & "  "
               & Files.Localization.Text ("runtime.smoke.vertices", Locale)
               & ": "
               & Natural_Text (Natural (Batch.Vertices.Length)));

            if Text_Status /= Files.Rendering.Text_Render_Success
              or else Glyphs.Status /= Files.Rendering.Text_Render_Success
              or else Glyphs.Glyphs.Is_Empty
            then
               Append_Line (Files.Localization.Text ("runtime.smoke.text_failed", Locale));
            end if;
         end;
      end loop;

      return To_String (Report);
   end Runtime_Smoke_Report;

   procedure Run is
      Arguments : String_Vectors.Vector;
      Config    : Run_Configuration;
      Result    : Startup_Result;
      Report    : Unbounded_String;
   begin
      for Index in 1 .. Ada.Command_Line.Argument_Count loop
         Arguments.Append (To_Unbounded_String (Ada.Command_Line.Argument (Index)));
      end loop;

      Config := Parse_Run_Configuration (Arguments);
      if Config.Mode = Help_Run then
         Ada.Text_IO.Put_Line (Help_Text);
         return;
      elsif Config.Mode = Version_Run then
         Ada.Text_IO.Put_Line (Version_Text);
         return;
      end if;

      Result := Resolve_Startup (Config.Paths, To_String (Config.Settings_Path));
      Report := To_Unbounded_String (Startup_Report (Result));
      if To_String (Report) /= "" then
         Ada.Text_IO.Put_Line (To_String (Report));
      end if;

      case Config.Mode is
         when Headless_Smoke_Run =>
            Ada.Text_IO.Put_Line (Runtime_Smoke_Report (Result));
            return;

         when Live_Smoke_Run =>
            declare
               Plan       : constant Files.Application.Windows.Live_Smoke_Plan :=
                 Files.Application.Windows.Live_Window_Smoke_Plan;
               Live_Result : constant Files.Application.Windows.Live_Smoke_Result :=
                 Files.Application.Windows.Run_Live_Window_Smoke (Result, Plan);
            begin
               Ada.Text_IO.Put_Line
                 (Files.Localization.Text (To_String (Live_Result.Error_Key)));
               Ada.Text_IO.Put_Line
                 (Files.Localization.Text ("runtime.smoke.vulkan_status")
                  & ": "
                  & Files.Rendering.Vulkan.Vulkan_Status'Image (Live_Result.Last_Status));
               Ada.Text_IO.Put_Line
                 (Files.Localization.Text ("runtime.smoke.vulkan_result")
                  & ": "
                  & Interfaces.Integer_32'Image (Live_Result.Last_Vk_Result));
               Ada.Text_IO.Put_Line
                 (Files.Localization.Text ("runtime.smoke.frames_attempted")
                  & ": "
                  & Natural'Image (Live_Result.Frames_Attempted));
               Ada.Text_IO.Put_Line
                 (Files.Localization.Text ("runtime.smoke.frames_presented")
                  & ": "
                  & Natural'Image (Live_Result.Frames_Presented));
               Ada.Text_IO.Put_Line
                 (Files.Localization.Text ("runtime.smoke.framebuffer_readback")
                  & ": "
                  & Boolean'Image (Live_Result.Framebuffer_Readback_Ready));
               Ada.Text_IO.Put_Line
                 (Files.Localization.Text ("runtime.smoke.framebuffer_hash")
                  & ": "
                  & Interfaces.Unsigned_32'Image (Live_Result.Last_Framebuffer_Hash));
               Ada.Text_IO.Put_Line
                 (Files.Localization.Text ("runtime.smoke.framebuffer_bytes")
                  & ": "
                  & Natural'Image (Live_Result.Last_Framebuffer_Bytes));
            end;
            return;

         when Help_Run =>
            return;

         when Version_Run =>
            return;

         when Desktop_Run =>
            null;
      end case;

      begin
         Files.Application.Windows.Run (Result);
      exception
         when Error : Files.Application.Windows.Desktop_Error =>
            Ada.Text_IO.Put_Line (Desktop_Error_Report (Ada.Exceptions.Exception_Message (Error)));
      end;
   end Run;

end Files.Application;
