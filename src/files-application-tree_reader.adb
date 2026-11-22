with Ada.Strings.Unbounded;
with Files.Application.Background_Slots;
with Files.IO.Errors;

package body Files.Application.Tree_Reader is
   use Ada.Strings.Unbounded;
   use type Files.Types.Listing_Options;

   --  What a read depends on besides the path.
   type Read_Policy is record
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options;
   end record;

   function Same (Left, Right : Read_Policy) return Boolean is
     (Files.File_Types."=" (Left.Classes, Right.Classes) and then Left.Options = Right.Options);

   function Read (Path : String; Policy : Read_Policy) return Files.File_System.Directory_Load_Result is
     (Files.File_System.Load_Subdirectories (Path, Policy.Classes, Policy.Options));

   function Unread return Files.File_System.Directory_Load_Result is
     ((Success   => False,
       Error_Key => To_Unbounded_String (Files.IO.Errors.Directory_Load_Key),
       others    => <>));

   --  A read, a failed one included, is handed out once: the node stops
   --  loading either way, and the next expand asks again.
   function Always (Load : Files.File_System.Directory_Load_Result) return Boolean is
      pragma Unreferenced (Load);
   begin
      return True;
   end Always;

   package Reader is new Files.Application.Background_Slots
     (Parameters  => Read_Policy,
      Result      => Files.File_System.Directory_Load_Result,
      Work        => Read,
      Failed      => Unread,
      Handed_Once => Always,
      "="         => Same);

   procedure Request
     (Owner   : Requester;
      Path    : String;
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options) is
   begin
      Reader.Request (Reader.Requester (Owner), Path, (Classes => Classes, Options => Options));
   end Request;

   procedure Take
     (Owner   : Requester;
      Path    : String;
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options;
      Load    : out Files.File_System.Directory_Load_Result;
      Ready   : out Boolean;
      Asked   : out Boolean) is
   begin
      Reader.Take (Reader.Requester (Owner), Path, (Classes => Classes, Options => Options), Load, Ready, Asked);
   end Take;

   procedure Release (Owner : Requester) is
   begin
      Reader.Release (Reader.Requester (Owner));
   end Release;

end Files.Application.Tree_Reader;
