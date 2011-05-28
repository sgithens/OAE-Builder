def send_internal_message(to, from, subject, body)
  req = Net::HTTP::Post.new("/~#{from}/message.create.html")
  req.set_form_data({
    "_charset_" => "utf-8",
    "sakai:body" => "test body #{from} => #{to}",
    "sakai:category" => "message",
    "sakai:from" => "#{from}",
    "sakai:messagebox" => "outbox",
    "sakai:sendstate" => "pending",
    "sakai:subject" => "test #{from} => #{to}",
    "sakai:to" => "internal:#{to}",
    "sakai:type" => "internal"
  })
  req.basic_auth("#{from}", "test")
  @localinstance.request(req)
end

def send_smtp_message(to, from, subject, body)
  req = Net::HTTP::Post.new("/~#{from}/message.create.html")
  req.set_form_data({
    "sakai:type" => "smtp",
    "sakai:sendstate" => "pending",
    "sakai:messagebox" => "pending",
    "sakai:to" => "internal:#{to}",
    "sakai:from" => "#{from}",
    "sakai:subject" => "test #{from} => #{to}",
    "sakai:body" => "test body #{from} => #{to}",
    "sakai:category" => "message",
    "_charset_" => "utf-8",
    "sakai:templatePath" => "/var/templates/email/new_message",
    "sakai:templateParams" => "sender=User #{from}|system=Sakai|subject=test #{from} => #{to}|body=test body #{from} => #{to}|link=http://localhost:8080/inbox"
  })
  req.basic_auth("#{from}", "test")
  @localinstance.request(req)
end

