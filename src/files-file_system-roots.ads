--  The roots operations of Files.File_System, extracted into
--  a concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.File_System.Roots is

   --  Return available filesystem root locations in deterministic order.
   --
   --  @return Root paths available on the host platform.
   function Available_Roots return Files.Types.String_Vectors.Vector;

   --  Return available filesystem root locations with labels and source kind.
   --
   --  @return Root entries available on the host platform.
   function Available_Root_Entries return Root_Entry_Vectors.Vector;

   --  Return the display-label token for a root location. The token is either a
   --  localization key (e.g. "root.home") or a "key|value" pair the renderer
   --  expands with a localized prefix and suffix (e.g. "root.favorite|<name>").
   --
   --  @param Path Root path.
   --  @param Kind Root classification.
   --  @return Label token for the renderer.
   function Root_Label (Path : String; Kind : Root_Kind) return String;

   --  Return diagnostics for root discovery without changing the root list.
   --
   --  @return Root discovery counts and policy flags.
   function Root_Discovery_Status return Root_Discovery_Diagnostics;

   --  Return root volume metadata capabilities for the current implementation.
   --
   --  @return Platform volume metadata capability flags.
   function Root_Volume_Capabilities_Of_Current_Environment
      return Root_Volume_Capabilities;

   --  Return filesystem edge-case handling metadata for the current implementation.
   --
   --  @return Recoverable filesystem edge-case behavior flags.
   function Filesystem_Edge_Case_Profile_Of_Current_Environment
      return Filesystem_Edge_Case_Profile;

   --  Return native filesystem adapter capabilities for the selected platform.
   --
   --  @param Adapter Platform adapter to inspect.
   --  @return Native trash and volume API binding status for Adapter.
   function Native_Platform_API_Profile_For
     (Adapter : Native_Platform_Adapter)
      return Native_Platform_API_Profile;

   --  Return best-effort volume details for a discovered root.
   --
   --  @param Root Root entry to describe.
   --  @return Volume details and known platform metadata flags.
   function Root_Volume_Details_For
     (Root : Root_Entry)
      return Root_Volume_Details;

   --  Return filetype metadata extraction policy for the current implementation.
   --
   --  @return Metadata extraction capability flags.
   function Filetype_Metadata_Policy_Of_Current_Implementation
      return Filetype_Metadata_Policy;

end Files.File_System.Roots;
