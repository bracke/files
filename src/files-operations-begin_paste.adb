separate (Files.Operations)
   function Begin_Paste
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result is
   begin
      return Begin_Paste_To
        (Model, Settings, Source_Paths, Files.Model.Current_Path (Model), Mode, From_Clipboard);
   end Begin_Paste;
