module ApplicationHelper
  def dummy_page_nav(title:, subtitle: nil, back_url: nil, back_label: "Home")
    content_for(:title, title)
    content_for(:subtitle, subtitle) if subtitle.present?
    flat_pack_page_nav(
      round: true,
      style: :default,
      back_href: back_url,
      back_tooltip: back_label
    )
  end
end
