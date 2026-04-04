$path = "d:\PTUD\Cardify_AI_English_Learning - Copy\lib\screens\flashcard_category_screen.dart"
$lines = Get-Content -Path $path
$start = ($lines | Select-String -Pattern "const Map<String, String> _vietnameseMeaningByWord = \{" | Select-Object -First 1).LineNumber
if (-not $start) { throw "Cannot find _vietnameseMeaningByWord" }

$entries = @()
for ($i = $start; $i -le $lines.Count; $i++) {
  $line = $lines[$i - 1].Trim()
  if ($line -eq '};') { break }
  if ($line -match "^'([^']+)'\s*:\s*'([^']*)',") {
    $entries += [pscustomobject]@{ word = $matches[1]; meaning_vi = $matches[2] }
  }
}
if ($entries.Count -eq 0) { throw "No pairs extracted" }

function Remove-Diacritics([string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) { return "" }
  $normalized = $text.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($ch in $normalized.ToCharArray()) {
    $uc = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
    if ($uc -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($ch) }
  }
  return $sb.ToString().Normalize([Text.NormalizationForm]::FormC).ToLower()
}

function Mask-Meaning([string]$text) {
  $vowels = 'aeiouyAEIOUY'
  $chars = $text.ToCharArray()
  for ($i = 0; $i -lt $chars.Length; $i++) {
    if ($vowels.Contains($chars[$i])) { $chars[$i] = '_' }
  }
  return -join $chars
}

$animals = @('cat','dog','bird','rabbit','tiger','lion','elephant','monkey','horse','cow','pig','sheep','duck','chicken','butterfly','bear','wolf','fox','deer','goat','donkey','eagle','parrot','dolphin','whale','shark','ant')
$vehicles = @('car','bus','train','plane','bike','motorbike','truck','taxi','ship','boat','helicopter','subway','scooter','bicycle','ambulance','van','tram','ferry','canoe','yacht','skateboard','rollerblade','wheelchair','cart','rocket','jet','glider')
$colors = @('blue','red','green','yellow','black','white','orange','purple','pink','brown','gray','gold','silver','violet','beige','turquoise','crimson','navy','olive','lavender','maroon','coral','amber','ivory','mint','peach','teal')
$foods = @('apple','banana','orange','bread','rice','noodle','soup','meat','fish','egg','milk','cheese','sugar','salt','butter','vegetable','fruit','pork','beef','shrimp','crab','juice','tea','coffee','honey','pepper')
$places = @('house','room','kitchen','bathroom','garden','street','city','village','school','hospital','office','market','park','bridge','library','area','zone','corner','center','border','front','back','left','right','above','below','middle')
$devices = @('computer','laptop','phone','tablet','keyboard','mouse','screen','printer','camera','robot','internet','software','hardware','server','application','code','program','database','network','password','security','update','download','upload','device','processor','clock','calendar','microwave','refrigerator','stove','kettle','toothbrush')
$times = @('hour','minute','second','day','week','month','year','morning','afternoon','evening','night','today','yesterday','tomorrow','date','schedule','deadline','moment','period','century','decade','season','spring','summer','winter','early','late')
$actions = @('run','walk','jump','swim','dance','sing','read','write','cook','clean','study','work','sleep','wake','play','listen','speak','watch','think','build','fix','drive','travel','practice','exercise','relax','celebrate')

$hardHints = @{
  'cat' = 'Gợi ý: con vật này kêu meo meo.'
  'dog' = 'Gợi ý: con vật này hay sủa và giữ nhà.'
  'bird' = 'Gợi ý: con vật này có cánh và hót trên cây.'
  'rabbit' = 'Gợi ý: con vật này có tai dài và thích ăn cà rốt.'
  'tiger' = 'Gợi ý: con vật này có vằn sọc đen trên bộ lông.'
  'lion' = 'Gợi ý: con vật này được gọi là chúa tể rừng xanh.'
  'monkey' = 'Gợi ý: con vật này leo trèo giỏi và thích ăn chuối.'
  'elephant' = 'Gợi ý: con vật này rất to và có vòi dài.'
  'horse' = 'Gợi ý: con vật này chạy nhanh và thường được cưỡi.'
  'cow' = 'Gợi ý: con vật này cho sữa và ăn cỏ trên đồng.'
  'pig' = 'Gợi ý: con vật này có mũi to, thường nuôi ở nông trại.'
  'sheep' = 'Gợi ý: con vật này có lông dày, lông dùng để dệt vải.'
  'duck' = 'Gợi ý: con vật này biết bơi và kêu cạp cạp.'
  'chicken' = 'Gợi ý: con vật này gáy ò ó o vào buổi sáng.'
  'butterfly' = 'Gợi ý: con vật này có đôi cánh đẹp và bay lượn quanh hoa.'
  'bear' = 'Gợi ý: con vật này to lớn, mạnh mẽ và thích mật ong.'
  'wolf' = 'Gợi ý: con vật này sống theo bầy và hay tru vào đêm.'
  'fox' = 'Gợi ý: con vật này nổi tiếng nhanh nhẹn và ranh mãnh.'
  'deer' = 'Gợi ý: con vật này có sừng nhánh, thường sống trong rừng.'
  'goat' = 'Gợi ý: con vật này leo núi giỏi và có bộ râu dưới cằm.'
  'donkey' = 'Gợi ý: con vật này nhìn giống ngựa, thường chở hàng ở vùng núi.'
  'eagle' = 'Gợi ý: đây là loài chim lớn, mắt rất tinh và bay cao.'
  'parrot' = 'Gợi ý: loài chim này có mỏ cong, có thể nhại lại tiếng người.'
  'dolphin' = 'Gợi ý: động vật biển thông minh, thường biểu diễn nhào lộn.'
  'whale' = 'Gợi ý: động vật biển khổng lồ, kích thước rất lớn.'
  'shark' = 'Gợi ý: động vật biển này có răng sắc và bơi rất nhanh.'
  'ant' = 'Gợi ý: con vật nhỏ xíu, thường đi thành hàng dài trên mặt đất.'
  'car' = 'Gợi ý: phương tiện bốn bánh dùng để chở người trên đường.'
  'bus' = 'Gợi ý: phương tiện công cộng chở nhiều người.'
  'train' = 'Gợi ý: phương tiện này chạy trên đường ray.'
  'plane' = 'Gợi ý: phương tiện này bay trên bầu trời.'
  'bike' = 'Gợi ý: phương tiện hai bánh, thường đạp bằng chân.'
  'motorbike' = 'Gợi ý: phương tiện hai bánh chạy bằng động cơ.'
  'truck' = 'Gợi ý: phương tiện chở hàng nặng và hàng cồng kềnh.'
  'taxi' = 'Gợi ý: xe chở khách có thể gọi đi ngay khi cần.'
  'ship' = 'Gợi ý: phương tiện lớn đi trên biển hoặc sông rộng.'
  'boat' = 'Gợi ý: phương tiện nhỏ hơn tàu, thường dùng để đi trên nước.'
  'helicopter' = 'Gợi ý: phương tiện bay có cánh quạt trên đỉnh.'
  'subway' = 'Gợi ý: tàu chạy ngầm dưới lòng đất.'
  'scooter' = 'Gợi ý: xe nhỏ gọn, thường dùng đi quãng ngắn.'
  'bicycle' = 'Gợi ý: xe hai bánh phải đạp bằng chân.'
  'ambulance' = 'Gợi ý: xe khẩn cấp chở người bệnh đến bệnh viện.'
  'van' = 'Gợi ý: xe chở hàng hoặc chở người loại nhỏ.'
  'tram' = 'Gợi ý: phương tiện chạy trên đường ray trong thành phố.'
  'ferry' = 'Gợi ý: phương tiện chở người qua sông hoặc biển ngắn.'
  'canoe' = 'Gợi ý: thuyền nhỏ, nhẹ và thường được chèo tay.'
  'yacht' = 'Gợi ý: thuyền sang trọng để đi chơi hoặc du ngoạn.'
  'skateboard' = 'Gợi ý: ván trượt dùng để đứng và di chuyển trên mặt phẳng.'
  'rollerblade' = 'Gợi ý: giày có bánh xe để trượt trên mặt đường.'
  'wheelchair' = 'Gợi ý: xe dành cho người khó đi lại.'
  'cart' = 'Gợi ý: xe đẩy dùng để chở đồ hoặc hàng hóa.'
  'rocket' = 'Gợi ý: phương tiện bay lên không gian rất nhanh.'
  'jet' = 'Gợi ý: máy bay phản lực bay tốc độ cao.'
  'glider' = 'Gợi ý: phương tiện bay lượn nhờ gió, không có động cơ lớn.'

  'blue' = 'Gợi ý: đây là màu của bầu trời trong xanh.'
  'red' = 'Gợi ý: đây là màu của quả dâu chín hoặc đèn báo dừng.'
  'green' = 'Gợi ý: đây là màu của lá cây và cỏ non.'
  'yellow' = 'Gợi ý: đây là màu của ánh nắng và nhiều bông hoa.'
  'black' = 'Gợi ý: đây là màu rất tối, giống bóng đêm.'
  'white' = 'Gợi ý: đây là màu của mây trắng và tuyết.'
  'purple' = 'Gợi ý: đây là màu tím đậm, thường tạo cảm giác sang.'
  'pink' = 'Gợi ý: đây là màu hồng dịu, hay gặp ở hoa và kẹo.'
  'brown' = 'Gợi ý: đây là màu nâu của đất và gỗ.'
  'gray' = 'Gợi ý: đây là màu xám của mây mù hoặc kim loại.'
  'gold' = 'Gợi ý: đây là màu vàng kim, thường gắn với sự quý giá.'
  'silver' = 'Gợi ý: đây là màu bạc sáng như kim loại.'
  'violet' = 'Gợi ý: đây là màu tím nhạt, gần với màu hoa oải hương.'
  'beige' = 'Gợi ý: đây là màu be nhẹ, rất dịu mắt.'
  'turquoise' = 'Gợi ý: đây là màu xanh ngọc pha xanh lam.'
  'crimson' = 'Gợi ý: đây là màu đỏ thẫm, đậm hơn đỏ thường.'
  'navy' = 'Gợi ý: đây là màu xanh hải quân rất đậm.'
  'olive' = 'Gợi ý: đây là màu xanh ô liu hơi ngả vàng.'
  'lavender' = 'Gợi ý: đây là màu tím oải hương nhẹ nhàng.'
  'maroon' = 'Gợi ý: đây là màu nâu đỏ trầm.'
  'coral' = 'Gợi ý: đây là màu san hô pha giữa hồng và cam.'
  'amber' = 'Gợi ý: đây là màu hổ phách ấm áp.'
  'ivory' = 'Gợi ý: đây là màu ngà rất nhạt.'
  'mint' = 'Gợi ý: đây là màu xanh bạc hà mát mắt.'
  'peach' = 'Gợi ý: đây là màu đào nhẹ và ấm.'
  'teal' = 'Gợi ý: đây là màu xanh mòng két pha xanh lam và xanh lục.'

  'apple' = 'Gợi ý: đây là loại quả giòn, thường có màu đỏ hoặc xanh.'
  'banana' = 'Gợi ý: đây là loại quả dài, vỏ vàng và ruột mềm.'
  'orange' = 'Gợi ý: đây là loại quả có múi, đồng thời cũng là tên một màu sắc tươi sáng.'
  'bread' = 'Gợi ý: đây là món ăn làm từ bột mì, hay dùng vào bữa sáng.'
  'rice' = 'Gợi ý: đây là món ăn chính của nhiều bữa cơm Việt.'
  'noodle' = 'Gợi ý: đây là món ăn dạng sợi, thường ăn với nước dùng.'
  'soup' = 'Gợi ý: đây là món nước nóng, thường ăn khi trời lạnh.'
  'meat' = 'Gợi ý: đây là thực phẩm từ động vật, như thịt heo hoặc bò.'
  'fish' = 'Gợi ý: đây là thực phẩm từ sông biển và cũng là tên một loài cá.'
  'egg' = 'Gợi ý: đây là thực phẩm có vỏ, thường lấy từ gà vịt.'
  'milk' = 'Gợi ý: đây là đồ uống màu trắng, rất quen thuộc với trẻ em.'
  'cheese' = 'Gợi ý: đây là thực phẩm từ sữa, có vị béo và mặn nhẹ.'
  'sugar' = 'Gợi ý: đây là nguyên liệu tạo vị ngọt.'
  'salt' = 'Gợi ý: đây là gia vị làm tăng vị mặn.'
  'butter' = 'Gợi ý: đây là nguyên liệu béo mềm, hay dùng với bánh mì.'
  'vegetable' = 'Gợi ý: đây là nhóm thực phẩm rau xanh và rau củ.'
  'fruit' = 'Gợi ý: đây là nhóm thực phẩm ngọt tự nhiên, thường mọng nước.'
  'pork' = 'Gợi ý: đây là thịt từ con heo.'
  'beef' = 'Gợi ý: đây là thịt từ con bò.'
  'shrimp' = 'Gợi ý: đây là loại hải sản nhỏ, có vỏ cứng.'
  'crab' = 'Gợi ý: đây là loại hải sản có càng và vỏ cứng.'
  'juice' = 'Gợi ý: đây là đồ uống ép từ trái cây.'
  'tea' = 'Gợi ý: đây là thức uống được pha từ lá trà.'
  'coffee' = 'Gợi ý: đây là thức uống thơm, thường có vị đắng nhẹ.'
  'honey' = 'Gợi ý: đây là chất ngọt do ong tạo ra.'
  'pepper' = 'Gợi ý: đây là gia vị có vị cay nồng.'

  'house' = 'Gợi ý: đây là nơi cả gia đình sinh sống.'
  'room' = 'Gợi ý: đây là một không gian nhỏ bên trong ngôi nhà.'
  'kitchen' = 'Gợi ý: đây là nơi nấu ăn trong nhà.'
  'bathroom' = 'Gợi ý: đây là nơi tắm rửa và vệ sinh cá nhân.'
  'garden' = 'Gợi ý: đây là khu vực trồng cây, hoa lá.'
  'street' = 'Gợi ý: đây là con đường có nhà cửa hai bên.'
  'city' = 'Gợi ý: đây là nơi tập trung đông dân cư, nhiều tòa nhà.'
  'village' = 'Gợi ý: đây là khu vực làng quê yên bình.'
  'school' = 'Gợi ý: đây là nơi học sinh đến học mỗi ngày.'
  'hospital' = 'Gợi ý: đây là nơi bác sĩ khám và chữa bệnh.'
  'office' = 'Gợi ý: đây là nơi làm việc của nhân viên, công ty.'
  'market' = 'Gợi ý: đây là nơi mua bán hàng hóa hằng ngày.'
  'park' = 'Gợi ý: đây là nơi có cây xanh để dạo chơi, nghỉ ngơi.'
  'bridge' = 'Gợi ý: đây là công trình nối hai bên qua sông hoặc đường.'
  'library' = 'Gợi ý: đây là nơi có nhiều sách để đọc và mượn.'
  'area' = 'Gợi ý: đây là một khu vực hoặc vùng cụ thể.'
  'zone' = 'Gợi ý: đây là một vùng được chia ra theo mục đích nào đó.'
  'corner' = 'Gợi ý: đây là chỗ giao nhau của hai cạnh hoặc hai đường.'
  'center' = 'Gợi ý: đây là vị trí ở giữa hoặc trung tâm.'
  'border' = 'Gợi ý: đây là đường ranh giới giữa hai khu vực.'
  'front' = 'Gợi ý: đây là phía ở trước.'
  'back' = 'Gợi ý: đây là phía ở sau.'
  'left' = 'Gợi ý: đây là phía bên trái.'
  'right' = 'Gợi ý: đây là phía bên phải.'
  'above' = 'Gợi ý: đây là vị trí ở phía trên.'
  'below' = 'Gợi ý: đây là vị trí ở phía dưới.'
  'middle' = 'Gợi ý: đây là vị trí ở giữa.'

  'computer' = 'Gợi ý: thiết bị này dùng để làm việc và học tập.'
  'laptop' = 'Gợi ý: đây là máy tính xách tay, có thể mang đi khắp nơi.'
  'phone' = 'Gợi ý: thiết bị này dùng để gọi điện và nhắn tin.'
  'tablet' = 'Gợi ý: đây là máy tính bảng, màn hình cảm ứng lớn.'
  'keyboard' = 'Gợi ý: đây là bộ phận có nhiều phím để gõ chữ.'
  'mouse' = 'Gợi ý: đây là thiết bị nhỏ để điều khiển con trỏ.'
  'screen' = 'Gợi ý: đây là phần hiển thị hình ảnh của máy tính.'
  'printer' = 'Gợi ý: đây là thiết bị dùng để in giấy.'
  'camera' = 'Gợi ý: đây là thiết bị dùng để chụp ảnh.'
  'robot' = 'Gợi ý: đây là máy móc tự động, có thể làm nhiều việc.'
  'internet' = 'Gợi ý: đây là mạng kết nối toàn cầu.'
  'software' = 'Gợi ý: đây là phần mềm chạy trên máy tính.'
  'hardware' = 'Gợi ý: đây là phần cứng, các bộ phận vật lý của máy.'
  'server' = 'Gợi ý: đây là máy chủ phục vụ dữ liệu hoặc dịch vụ.'
  'application' = 'Gợi ý: đây là ứng dụng bạn cài để sử dụng trên thiết bị.'
  'code' = 'Gợi ý: đây là mã viết ra để máy tính hiểu.'
  'program' = 'Gợi ý: đây là một chương trình được máy tính chạy.'
  'database' = 'Gợi ý: đây là cơ sở dữ liệu lưu trữ thông tin.'
  'network' = 'Gợi ý: đây là hệ thống kết nối nhiều thiết bị với nhau.'
  'password' = 'Gợi ý: đây là mật khẩu để bảo vệ tài khoản.'
  'security' = 'Gợi ý: đây là sự bảo vệ khỏi rủi ro hoặc tấn công.'
  'update' = 'Gợi ý: đây là hành động cập nhật lên phiên bản mới.'
  'download' = 'Gợi ý: đây là hành động tải dữ liệu về máy.'
  'upload' = 'Gợi ý: đây là hành động tải dữ liệu lên mạng.'
  'device' = 'Gợi ý: đây là thiết bị điện tử hoặc máy móc.'
  'processor' = 'Gợi ý: đây là bộ xử lý, phần “đầu não” của máy.'
  'clock' = 'Gợi ý: đây là vật dùng để xem giờ.'
  'calendar' = 'Gợi ý: đây là lịch dùng để xem ngày tháng.'
  'microwave' = 'Gợi ý: đây là lò vi sóng để hâm nóng thức ăn.'
  'refrigerator' = 'Gợi ý: đây là tủ lạnh để giữ thực phẩm mát.'
  'stove' = 'Gợi ý: đây là bếp dùng để nấu ăn.'
  'kettle' = 'Gợi ý: đây là ấm đun nước.'
  'toothbrush' = 'Gợi ý: đây là bàn chải dùng để đánh răng.'

  'hour' = 'Gợi ý: đây là đơn vị đo thời gian, dài hơn phút.'
  'minute' = 'Gợi ý: đây là đơn vị thời gian, ngắn hơn giờ.'
  'second' = 'Gợi ý: đây là đơn vị thời gian rất ngắn.'
  'day' = 'Gợi ý: đây là một ngày trong tuần hoặc 24 giờ.'
  'week' = 'Gợi ý: đây là khoảng thời gian gồm 7 ngày.'
  'month' = 'Gợi ý: đây là khoảng thời gian trong năm, có 12 phần.'
  'year' = 'Gợi ý: đây là khoảng thời gian gồm 12 tháng.'
  'morning' = 'Gợi ý: đây là thời điểm bắt đầu của một ngày.'
  'afternoon' = 'Gợi ý: đây là khoảng thời gian sau buổi trưa.'
  'evening' = 'Gợi ý: đây là thời điểm khi trời đã xế chiều.'
  'night' = 'Gợi ý: đây là thời gian khi trời tối.'
  'today' = 'Gợi ý: đây là ngày hiện tại.'
  'yesterday' = 'Gợi ý: đây là ngày trước hôm nay.'
  'tomorrow' = 'Gợi ý: đây là ngày sau hôm nay.'
  'date' = 'Gợi ý: đây là ngày tháng cụ thể trên lịch.'
  'schedule' = 'Gợi ý: đây là kế hoạch hoặc lịch trình làm việc.'
  'deadline' = 'Gợi ý: đây là thời hạn phải hoàn thành công việc.'
  'moment' = 'Gợi ý: đây là một khoảnh khắc ngắn.'
  'period' = 'Gợi ý: đây là một khoảng thời gian.'
  'century' = 'Gợi ý: đây là một thế kỷ, gồm 100 năm.'
  'decade' = 'Gợi ý: đây là một thập kỷ, gồm 10 năm.'
  'season' = 'Gợi ý: đây là một mùa trong năm.'
  'spring' = 'Gợi ý: đây là mùa xuân.'
  'summer' = 'Gợi ý: đây là mùa hè.'
  'winter' = 'Gợi ý: đây là mùa đông.'
  'early' = 'Gợi ý: từ này diễn tả sự sớm hơn bình thường.'
  'late' = 'Gợi ý: từ này diễn tả sự muộn hơn bình thường.'

  'run' = 'Gợi ý: đây là hành động di chuyển rất nhanh bằng chân.'
  'walk' = 'Gợi ý: đây là hành động đi bộ chậm rãi.'
  'jump' = 'Gợi ý: đây là hành động bật người lên khỏi mặt đất.'
  'swim' = 'Gợi ý: đây là hành động di chuyển trong nước.'
  'dance' = 'Gợi ý: đây là hành động nhảy múa theo nhịp.'
  'sing' = 'Gợi ý: đây là hành động cất giọng thành bài hát.'
  'read' = 'Gợi ý: đây là hành động xem và hiểu chữ viết.'
  'write' = 'Gợi ý: đây là hành động dùng bút hoặc bàn phím để tạo chữ.'
  'cook' = 'Gợi ý: đây là hành động nấu thức ăn.'
  'clean' = 'Gợi ý: đây là hành động dọn dẹp cho gọn gàng.'
  'study' = 'Gợi ý: đây là hành động học tập, ôn bài.'
  'work' = 'Gợi ý: đây là hành động làm việc để tạo ra kết quả.'
  'sleep' = 'Gợi ý: đây là trạng thái nghỉ ngơi vào ban đêm.'
  'wake' = 'Gợi ý: đây là hành động thức dậy sau khi ngủ.'
  'play' = 'Gợi ý: đây là hành động vui chơi hoặc giải trí.'
  'listen' = 'Gợi ý: đây là hành động lắng nghe bằng tai.'
  'speak' = 'Gợi ý: đây là hành động nói ra bằng miệng.'
  'watch' = 'Gợi ý: đây là hành động nhìn theo dõi một thứ gì đó.'
  'think' = 'Gợi ý: đây là hành động suy nghĩ trong đầu.'
  'build' = 'Gợi ý: đây là hành động xây dựng hoặc tạo ra.'
  'fix' = 'Gợi ý: đây là hành động sửa chữa thứ bị hỏng.'
  'drive' = 'Gợi ý: đây là hành động lái xe.'
  'travel' = 'Gợi ý: đây là hành động đi đến nơi khác để khám phá.'
  'practice' = 'Gợi ý: đây là hành động luyện tập nhiều lần để giỏi hơn.'
  'exercise' = 'Gợi ý: đây là hành động vận động để khỏe mạnh.'
  'relax' = 'Gợi ý: đây là hành động thư giãn, nghỉ ngơi.'
  'celebrate' = 'Gợi ý: đây là hành động ăn mừng một dịp vui.'
}

$used = [System.Collections.Generic.HashSet[string]]::new()
$result = @()

for ($i = 0; $i -lt $entries.Count; $i++) {
  $e = $entries[$i]
  $word = $e.word
  $meaning = $e.meaning_vi
  $norm = Remove-Diacritics $meaning
  $masked = Mask-Meaning $meaning
  $lettersOnly = ($norm -replace '[^a-z]','')
  $len = $lettersOnly.Length
  $first = if ($lettersOnly.Length -gt 0) { $lettersOnly.Substring(0,1).ToUpper() } else { '' }

  $group = 'general'
  if ($animals -contains $word) { $group = 'animal' }
  elseif ($vehicles -contains $word) { $group = 'vehicle' }
  elseif ($colors -contains $word) { $group = 'color' }
  elseif ($foods -contains $word) { $group = 'food' }
  elseif ($places -contains $word) { $group = 'place' }
  elseif ($devices -contains $word) { $group = 'device' }
  elseif ($times -contains $word) { $group = 'time' }
  elseif ($actions -contains $word) { $group = 'action' }

  if ($hardHints.ContainsKey($word)) {
    $hint = $hardHints[$word]
  } else {
    switch ($group) {
      'animal' { $hint = "Gợi ý: đây là tên một con vật, dạng chữ '$masked'." }
      'vehicle' { $hint = "Gợi ý: đây là tên một phương tiện di chuyển, dạng chữ '$masked'." }
      'color' { $hint = "Gợi ý: đây là tên một màu sắc, dạng chữ '$masked'." }
      'food' { $hint = "Gợi ý: đây là món ăn/thực phẩm quen thuộc, dạng chữ '$masked'." }
      'place' { $hint = "Gợi ý: đây là địa điểm/vị trí quen thuộc, dạng chữ '$masked'." }
      'device' { $hint = "Gợi ý: từ này liên quan đến công nghệ/thiết bị, dạng chữ '$masked'." }
      'time' { $hint = "Gợi ý: đây là từ chỉ thời gian, dạng chữ '$masked'." }
      'action' { $hint = "Gợi ý: đây là từ mô tả hành động, dạng chữ '$masked'." }
      default { $hint = "Gợi ý: từ này bắt đầu bằng '$first', có $len chữ cái, dạng '$masked'." }
    }
  }

  $uniqueHint = $hint
  $counter = 1
  while ($used.Contains($uniqueHint)) {
    $counter++
    $uniqueHint = "$hint (biến thể $counter)"
  }
  [void]$used.Add($uniqueHint)

  $result += [pscustomobject]@{
    word = $word
    meaning_vi = $meaning
    hint_vi = $uniqueHint
    hint_group = $group
    normalized_meaning = $norm
    masked_meaning = $masked
  }
}

$outDir = "d:\PTUD\Cardify_AI_English_Learning - Copy\assets\data"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = Join-Path $outDir "vocabulary_hints_vi.json"
$payload = [pscustomobject]@{
  version = 2
  generated_at = (Get-Date).ToString("s")
  total_words = $result.Count
  language = "vi"
  unique_hints = $used.Count
  items = $result
}
$payload | ConvertTo-Json -Depth 8 | Set-Content -Path $outFile -Encoding UTF8
Write-Output "Generated: $outFile"
Write-Output "Total items: $($result.Count)"
Write-Output "Unique hints: $($used.Count)"
