with Files.Background_Slots;

package body Files.Preview_Decoder is

   function Decode (Path : String; Size : Positive) return Files.Images.Decoded_Image is
     (Files.Images.Decode_Image_To_Pixels (Path, Size));

   function Decoded (Image : Files.Images.Decoded_Image) return Boolean is (Image.Available);

   function No_Image return Files.Images.Decoded_Image is ((others => <>));

   package Decoder is new Files.Background_Slots
     (Parameters  => Positive,
      Result      => Files.Images.Decoded_Image,
      Work        => Decode,
      Failed      => No_Image,
      Handed_Once => Decoded);

   procedure Request (Owner : Requester; Path : String; Size : Positive) is
   begin
      Decoder.Request (Decoder.Requester (Owner), Path, Size);
   end Request;

   procedure Take
     (Owner : Requester;
      Path  : String;
      Image : out Files.Images.Decoded_Image;
      Ready : out Boolean;
      Asked : out Boolean) is
   begin
      Decoder.Take (Decoder.Requester (Owner), Path, Image, Ready, Asked);
   end Take;

end Files.Preview_Decoder;
