module IssuesSummaryGraphHelper
  SUMMARY_IMAGE_WIDTH = 240
  SUMMARY_IMAGE_HEIGHT = 200

  def generate_summary_graph
    imgl = Magick::ImageList.new
    imgl.new_image(SUMMARY_IMAGE_WIDTH, SUMMARY_IMAGE_HEIGHT)
    gc = Magick::Draw.new

    gc.stroke('transparent')
    gc.fill('black')

    closed_issue_status_ids = IssueStatus.find(:all, :conditions => ['is_closed = ?', true]).map {|st| st.id}
    closed_issue_map = {}
    open_issue_map = {}
    issues = @project.issues
    issues.each do |issue|
      open_issue_map[issue.created_on.strftime('%Y%m%d')] ||= 0
      open_issue_map[issue.created_on.strftime('%Y%m%d')] += 1 

      closed_date = issue_closed_date(issue, closed_issue_status_ids)
      if closed_date
        closed_issue_map[closed_date.strftime('%Y%m%d')] ||= 0
        closed_issue_map[closed_date.strftime('%Y%m%d')] += 1
      end      
    end

    sorted_open_issue_map = open_issue_map.sort
    sorted_closed_issue_map = closed_issue_map.sort
    if sorted_open_issue_map.length == 0 and sorted_closed_issue_map.length == 0
      gc.draw(imgl)
      imgl.format = 'PNG'
      return imgl.to_blob
    end
    
    if sorted_open_issue_map.length == 0
      start_date = Date.parse(sorted_closed_issue_map[0][0])
      end_date = Date.parse(sorted_closed_issue_map[-1][0])
    elsif sorted_closed_issue_map.length == 0 
      start_date = Date.parse(sorted_sorted_open_issue_map[0][0])
      end_date = Date.parse(sorted_open_issue_map[-1][0])
    else
      start_date = Date.parse((sorted_open_issue_map[0][0] < sorted_closed_issue_map[0][0]) ? sorted_open_issue_map[0][0] : sorted_closed_issue_map[0][0])
      end_date = Date.parse((sorted_open_issue_map[-1][0] > sorted_closed_issue_map[-1][0]) ? sorted_open_issue_map[-1][0] : sorted_closed_issue_map[-1][0])
    end
    duration = ((end_date - start_date))
    logger.info "*************************************"
    logger.info start_date
    logger.info end_date
    logger.info duration
    logger.info "*************************************"

    draw_line(open_issue_map, start_date, duration, gc, 'red', issues.size)
    draw_line(closed_issue_map, start_date, duration, gc, 'black', issues.size)

    closed_issue_map.each do |key, value|
      logger.info "#{key} #{value}"
    end

    gc.draw(imgl)
    imgl.format = 'PNG'
    imgl.to_blob
  end

  def draw_line(issue_map, start_date, duration, gc, color, issue_num)
    gc.fill(color)
    x = 0
    y = SUMMARY_IMAGE_HEIGHT
    prev_x = 0
    prev_y = SUMMARY_IMAGE_HEIGHT
    sum = 0
    (duration + 1).to_i.times do |i|
      x += (SUMMARY_IMAGE_WIDTH / (duration + 1))
      sum += issue_map[(start_date + i).strftime('%Y%m%d')] || 0
      if issue_map[(start_date + i).strftime('%Y%m%d')]
        y = SUMMARY_IMAGE_HEIGHT.to_f * (1 - (sum.to_f / issue_num.to_f))
      end
      gc.line(prev_x, prev_y, x, y)
      logger.info "-------------------------------"
      logger.info "i = #{i}, (x, y) = (#{x}, #{y}), date = #{(start_date + i).strftime('%Y%m%d')}, num = #{issue_map[(start_date + i).strftime('%Y%m%d')]}"
      logger.info "-------------------------------"
      prev_x = x
      prev_y = y
    end
  end

  def issue_closed_date(issue, closed_issue_status_ids)
    issue.journals.each do |journal|
      journal.details.each do |detail|
        next unless detail.prop_key == 'status_id'
        if closed_issue_status_ids.include?(detail.value.to_i)
          return journal.created_on
        end
      end
    end
    nil
  end
end
