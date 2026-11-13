with Files.Settings_Sharing;
separate (Files.Application.Windows)
   procedure Share_Settings_From
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      Index           : Positive)
   is
      function Revision (Runtimes : Runtime_Window_Vectors.Vector; Window : Positive) return Natural is
        (Files.Model.Settings_Revision (Runtimes (Window).Model));

      function Synced_Revision (Runtimes : Runtime_Window_Vectors.Vector; Window : Positive) return Natural is
        (Runtimes (Window).Synced_Settings_Revision);

      procedure Mark_Synced
        (Runtimes    : in out Runtime_Window_Vectors.Vector;
         Window      : Positive;
         At_Revision : Natural) is
      begin
         Runtimes (Window).Synced_Settings_Revision := At_Revision;
      end Mark_Synced;

      procedure Adopt
        (Runtimes : in out Runtime_Window_Vectors.Vector;
         Target   : Positive;
         Source   : Positive) is
      begin
         Files.Settings_Sharing.Adopt_Window
           (Model             => Runtimes (Target).Model,
            Settings          => Runtimes (Target).Settings,
            Shared            => Runtimes (Source).Settings,
            Frame_Cache_Valid => Runtimes (Target).Frame_Cache_Valid);
      end Adopt;

      procedure Share is new Files.Settings_Sharing.Share_From
        (Window_Set      => Runtime_Window_Vectors.Vector,
         Revision        => Revision,
         Synced_Revision => Synced_Revision,
         Mark_Synced     => Mark_Synced,
         Adopt           => Adopt);
   begin
      Share (Runtime_Windows, Runtime_Windows.First_Index, Runtime_Windows.Last_Index, Index);
   end Share_Settings_From;
